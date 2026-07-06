package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// CycleShare is a user's opt-in, minimal cycle summary (one row per user).
type CycleShare struct {
	UserID       string
	Phase        string
	CycleDay     *int
	PeriodInDays *int
	Note         *string
	UpdatedAt    time.Time
}

// UpsertCycleShare stores the user's currently-shared cycle summary.
func (s *Store) UpsertCycleShare(ctx context.Context, userID, phase string, cycleDay, periodInDays *int, note *string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO cycle_shares (user_id, phase, cycle_day, period_in_days, note, updated_at)
		 VALUES ($1, $2, $3, $4, $5, now())
		 ON CONFLICT (user_id)
		 DO UPDATE SET phase = $2, cycle_day = $3, period_in_days = $4, note = $5, updated_at = now()`,
		userID, phase, cycleDay, periodInDays, note)
	return err
}

// GetCycleShare returns the user's shared cycle summary, if any.
func (s *Store) GetCycleShare(ctx context.Context, userID string) (CycleShare, error) {
	var c CycleShare
	err := s.pool.QueryRow(ctx,
		`SELECT user_id, phase, cycle_day, period_in_days, note, updated_at FROM cycle_shares WHERE user_id = $1`, userID).
		Scan(&c.UserID, &c.Phase, &c.CycleDay, &c.PeriodInDays, &c.Note, &c.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return CycleShare{}, ErrNotFound
	}
	return c, err
}

// DeleteCycleShare purges the user's shared cycle summary (stop sharing).
func (s *Store) DeleteCycleShare(ctx context.Context, userID string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM cycle_shares WHERE user_id = $1`, userID)
	return err
}
