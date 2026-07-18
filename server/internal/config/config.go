package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime configuration, loaded from environment variables.
type Config struct {
	Env             string
	HTTPPort        string
	DatabaseURL     string
	JWTSecret       []byte
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
	AppleClientIDs  []string
	APNS            APNSConfig
	AllowedOrigins  []string
	MediaDir        string

	FreeStorageBytes    int64
	PremiumStorageBytes int64

	// AnthropicAPIKey enables the Couples Debate AI judge. When empty, the judge
	// falls back to an offline heuristic so the game still works.
	AnthropicAPIKey string
	AnthropicModel  string
}

// APNSConfig holds Apple Push Notification service credentials.
type APNSConfig struct {
	KeyPath    string
	KeyID      string
	TeamID     string
	Topic      string
	Production bool
}

// Load reads configuration from the environment, applying sensible defaults for
// local development and validating anything that is required.
func Load() (*Config, error) {
	cfg := &Config{
		Env:             env("APP_ENV", "dev"),
		HTTPPort:        env("HTTP_PORT", "8080"),
		DatabaseURL:     env("DATABASE_URL", ""),
		JWTSecret:       []byte(env("JWT_SECRET", "")),
		AccessTokenTTL:  envDuration("ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL: envDuration("REFRESH_TOKEN_TTL", 720*time.Hour),
		AppleClientIDs:  envList("APPLE_CLIENT_IDS", "us.elbek.com"),
		APNS: APNSConfig{
			KeyPath:    env("APNS_KEY_PATH", ""),
			KeyID:      env("APNS_KEY_ID", ""),
			TeamID:     env("APNS_TEAM_ID", ""),
			Topic:      env("APNS_TOPIC", "us.elbek.com"),
			Production: envBool("APNS_PRODUCTION", false),
		},
		AllowedOrigins:      envList("CORS_ALLOWED_ORIGINS", "*"),
		MediaDir:            env("MEDIA_DIR", "./media-data"),
		FreeStorageBytes:    envInt64("FREE_STORAGE_BYTES", 2<<30),   // 2 GiB
		PremiumStorageBytes: envInt64("PREMIUM_STORAGE_BYTES", 30<<30), // 30 GiB

		AnthropicAPIKey: env("ANTHROPIC_API_KEY", ""),
		AnthropicModel:  env("ANTHROPIC_MODEL", "claude-opus-4-8"),
	}

	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	if len(cfg.JWTSecret) < 16 {
		return nil, fmt.Errorf("JWT_SECRET must be set to at least 16 characters")
	}
	return cfg, nil
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envList(key, def string) []string {
	parts := strings.Split(env(key, def), ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if s := strings.TrimSpace(p); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func envBool(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return def
}

func envInt64(key string, def int64) int64 {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			return n
		}
	}
	return def
}

func envDuration(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}
