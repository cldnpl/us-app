package db

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib" // database/sql driver for goose
	"github.com/pressly/goose/v3"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// Connect opens a pgx connection pool, retrying so the process can start
// alongside a Postgres container that is still becoming ready.
func Connect(ctx context.Context, url string, logger *slog.Logger) (*pgxpool.Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}
	poolCfg.MaxConns = 10

	var lastErr error
	for attempt := 1; attempt <= 15; attempt++ {
		pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
		if err == nil {
			pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
			err = pool.Ping(pingCtx)
			cancel()
			if err == nil {
				logger.Info("connected to postgres")
				return pool, nil
			}
			pool.Close()
		}
		lastErr = err
		logger.Warn("waiting for postgres", "attempt", attempt, "err", err)
		time.Sleep(2 * time.Second)
	}
	return nil, fmt.Errorf("connect to postgres: %w", lastErr)
}

// Migrate applies all embedded goose migrations using a standard database/sql
// connection (goose does not support pgxpool directly).
func Migrate(url string, logger *slog.Logger) error {
	sqlDB, err := sql.Open("pgx", url)
	if err != nil {
		return fmt.Errorf("open sql db: %w", err)
	}
	defer sqlDB.Close()

	goose.SetBaseFS(migrationsFS)
	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("set goose dialect: %w", err)
	}
	if err := goose.Up(sqlDB, "migrations"); err != nil {
		return fmt.Errorf("apply migrations: %w", err)
	}
	logger.Info("database migrations applied")
	return nil
}
