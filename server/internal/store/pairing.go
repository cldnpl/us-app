package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

var (
	ErrAlreadyPaired  = errors.New("already paired")
	ErrSelfPair       = errors.New("cannot pair with self")
	ErrPairingInvalid = errors.New("pairing code invalid or expired")
)

func (s *Store) CreatePairingCode(ctx context.Context, inviterID, code string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO pairing_codes (code, inviter_user_id, expires_at) VALUES ($1, $2, $3)`,
		code, inviterID, expiresAt)
	return err
}

func (s *Store) PairingCodeExists(ctx context.Context, code string) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pairing_codes WHERE code = $1)`, code).Scan(&exists)
	return exists, err
}

// GetActivePairingCode returns the inviter's most recent unused, unexpired code,
// so the same code is shown each time the pairing screen is opened.
func (s *Store) GetActivePairingCode(ctx context.Context, inviterID string) (code string, expiresAt time.Time, err error) {
	err = s.pool.QueryRow(ctx,
		`SELECT code, expires_at FROM pairing_codes
		 WHERE inviter_user_id = $1 AND used_at IS NULL AND expires_at > now()
		 ORDER BY created_at DESC LIMIT 1`, inviterID).Scan(&code, &expiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", time.Time{}, ErrNotFound
	}
	return code, expiresAt, err
}

// RedeemPairing atomically validates a code and links the inviter and redeemer
// into a new couple. It enforces that neither party is already paired.
func (s *Store) RedeemPairing(ctx context.Context, code, redeemerID string) (Couple, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return Couple{}, err
	}
	defer tx.Rollback(ctx)

	var inviterID string
	err = tx.QueryRow(ctx,
		`SELECT inviter_user_id FROM pairing_codes
		 WHERE code = $1 AND used_at IS NULL AND expires_at > now()
		 FOR UPDATE`, code).Scan(&inviterID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Couple{}, ErrPairingInvalid
	}
	if err != nil {
		return Couple{}, err
	}
	if inviterID == redeemerID {
		return Couple{}, ErrSelfPair
	}

	var count int
	if err = tx.QueryRow(ctx,
		`SELECT count(*) FROM couple_members WHERE user_id IN ($1, $2)`,
		inviterID, redeemerID).Scan(&count); err != nil {
		return Couple{}, err
	}
	if count > 0 {
		return Couple{}, ErrAlreadyPaired
	}

	var c Couple
	if err = tx.QueryRow(ctx,
		`INSERT INTO couples DEFAULT VALUES RETURNING `+coupleCols).
		Scan(&c.ID, &c.StartDate, &c.Status, &c.CreatedAt); err != nil {
		return Couple{}, err
	}
	if _, err = tx.Exec(ctx,
		`INSERT INTO couple_members (couple_id, user_id, role)
		 VALUES ($1, $2, 'member'), ($1, $3, 'member')`,
		c.ID, inviterID, redeemerID); err != nil {
		return Couple{}, err
	}
	if _, err = tx.Exec(ctx, `UPDATE pairing_codes SET used_at = now() WHERE code = $1`, code); err != nil {
		return Couple{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return Couple{}, err
	}
	return c, nil
}
