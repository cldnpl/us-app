package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sharepact/us/internal/auth"
	"github.com/sharepact/us/internal/config"
	"github.com/sharepact/us/internal/db"
	httpapi "github.com/sharepact/us/internal/http"
	"github.com/sharepact/us/internal/media"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	if err := run(logger); err != nil {
		logger.Error("fatal error", "err", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx := context.Background()

	pool, err := db.Connect(ctx, cfg.DatabaseURL, logger)
	if err != nil {
		return err
	}
	defer pool.Close()

	if err := db.Migrate(cfg.DatabaseURL, logger); err != nil {
		return err
	}

	// Push: real APNs sender when credentials are configured, else log-only.
	var sender push.Sender = push.NewLogSender(logger)
	if cfg.APNS.KeyPath != "" && cfg.APNS.KeyID != "" && cfg.APNS.TeamID != "" {
		if s, perr := push.NewAPNsSender(cfg.APNS.KeyPath, cfg.APNS.KeyID, cfg.APNS.TeamID, cfg.APNS.Topic, cfg.APNS.Production); perr != nil {
			logger.Warn("apns unavailable, using log sender", "err", perr)
		} else {
			sender = s
			logger.Info("apns push enabled")
		}
	}

	mediaStore, err := media.NewStorage(cfg.MediaDir)
	if err != nil {
		return err
	}

	router := httpapi.NewRouter(httpapi.Deps{
		Config: cfg,
		Pool:   pool,
		Logger: logger,
		Store:  store.New(pool),
		Apple:  auth.NewAppleVerifier(cfg.AppleClientIDs),
		Push:   sender,
		Media:  mediaStore,
	})

	srv := &http.Server{
		Addr:              ":" + cfg.HTTPPort,
		Handler:           router,
		ReadHeaderTimeout: 10 * time.Second,
	}

	shutdownErr := make(chan error, 1)
	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit
		logger.Info("shutdown signal received")
		shutCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		shutdownErr <- srv.Shutdown(shutCtx)
	}()

	logger.Info("http server listening", "port", cfg.HTTPPort, "env", cfg.Env)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return <-shutdownErr
}
