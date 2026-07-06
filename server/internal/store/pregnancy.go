package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// PregnancyShare is a user's opt-in shared due date (one row per user).
type PregnancyShare struct {
	UserID    string
	DueDate   time.Time
	UpdatedAt time.Time
}

// UpsertPregnancyShare stores the user's shared due date.
func (s *Store) UpsertPregnancyShare(ctx context.Context, userID string, dueDate time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO pregnancy_shares (user_id, due_date, updated_at)
		 VALUES ($1, $2, now())
		 ON CONFLICT (user_id)
		 DO UPDATE SET due_date = $2, updated_at = now()`,
		userID, dueDate)
	return err
}

// GetPregnancyShare returns the user's shared due date, if any.
func (s *Store) GetPregnancyShare(ctx context.Context, userID string) (PregnancyShare, error) {
	var p PregnancyShare
	err := s.pool.QueryRow(ctx,
		`SELECT user_id, due_date, updated_at FROM pregnancy_shares WHERE user_id = $1`, userID).
		Scan(&p.UserID, &p.DueDate, &p.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return PregnancyShare{}, ErrNotFound
	}
	return p, err
}

// DeletePregnancyShare purges the user's shared due date (stop sharing).
func (s *Store) DeletePregnancyShare(ctx context.Context, userID string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM pregnancy_shares WHERE user_id = $1`, userID)
	return err
}
