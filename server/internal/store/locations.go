package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type Location struct {
	UserID      string
	Lat         float64
	Lng         float64
	Accuracy    *float64
	SharingMode string
	ExpiresAt   *time.Time
	UpdatedAt   time.Time
}

// UpsertLocation stores the user's currently-shared location (one row per user).
func (s *Store) UpsertLocation(ctx context.Context, userID string, lat, lng float64, accuracy *float64, mode string, expiresAt *time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO locations (user_id, lat, lng, accuracy, sharing_mode, expires_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, now())
		 ON CONFLICT (user_id)
		 DO UPDATE SET lat = $2, lng = $3, accuracy = $4, sharing_mode = $5, expires_at = $6, updated_at = now()`,
		userID, lat, lng, accuracy, mode, expiresAt)
	return err
}

// GetLocation returns the user's active (non-expired) shared location.
func (s *Store) GetLocation(ctx context.Context, userID string) (Location, error) {
	var l Location
	err := s.pool.QueryRow(ctx,
		`SELECT user_id, lat, lng, accuracy, sharing_mode, expires_at, updated_at FROM locations
		 WHERE user_id = $1 AND (expires_at IS NULL OR expires_at > now())`, userID).
		Scan(&l.UserID, &l.Lat, &l.Lng, &l.Accuracy, &l.SharingMode, &l.ExpiresAt, &l.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Location{}, ErrNotFound
	}
	return l, err
}

// DeleteLocation purges the user's shared coordinates (stop sharing / ghost mode).
func (s *Store) DeleteLocation(ctx context.Context, userID string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM locations WHERE user_id = $1`, userID)
	return err
}
