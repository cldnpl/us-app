package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// ClaimNotification reserves the right to send `kind` to this couple now.
//
// It returns true only when the same kind has not been sent within `window`,
// and the check-and-set is a single atomic statement — so a burst of concurrent
// requests (or two server instances running the same daily job) produces one
// notification, not one per caller.
func (s *Store) ClaimNotification(ctx context.Context, coupleID, kind string, window time.Duration) (bool, error) {
	var claimed bool
	err := s.pool.QueryRow(ctx,
		`INSERT INTO notification_marks (couple_id, kind) VALUES ($1, $2)
		 ON CONFLICT (couple_id, kind) DO UPDATE SET sent_at = now()
		 WHERE notification_marks.sent_at < now() - make_interval(secs => $3)
		 RETURNING true`,
		coupleID, kind, window.Seconds()).Scan(&claimed)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil // sent too recently
	}
	return claimed, err
}
