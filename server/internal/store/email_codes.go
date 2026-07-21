package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// ErrEmailCodeInvalid covers every "this code will not work" case — wrong,
// expired, already spent, or too many failed attempts — so the API can answer
// with one message and leak nothing about which it was.
var ErrEmailCodeInvalid = errors.New("email change code invalid or expired")

// MaxEmailCodeAttempts is how many wrong guesses a single code tolerates before
// it is burned.
const MaxEmailCodeAttempts = 5

type EmailChangeCode struct {
	ID        string
	UserID    string
	NewEmail  string
	CodeHash  string
	Attempts  int
	ExpiresAt time.Time
}

// CreateEmailChangeCode voids any pending codes for the user and stores a new
// one, so only the most recently requested code is ever live.
func (s *Store) CreateEmailChangeCode(ctx context.Context, userID, newEmail, codeHash string, expiresAt time.Time) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if _, err = tx.Exec(ctx,
		`UPDATE email_change_codes SET used_at = now()
		 WHERE user_id = $1 AND used_at IS NULL`, userID); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx,
		`INSERT INTO email_change_codes (user_id, new_email, code_hash, expires_at)
		 VALUES ($1, $2, $3, $4)`,
		userID, newEmail, codeHash, expiresAt); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// GetPendingEmailChange returns the user's live code row, if any.
func (s *Store) GetPendingEmailChange(ctx context.Context, userID string) (EmailChangeCode, error) {
	var c EmailChangeCode
	err := s.pool.QueryRow(ctx,
		`SELECT id, user_id, new_email, code_hash, attempts, expires_at
		 FROM email_change_codes
		 WHERE user_id = $1 AND used_at IS NULL AND expires_at > now()
		 ORDER BY created_at DESC LIMIT 1`, userID).
		Scan(&c.ID, &c.UserID, &c.NewEmail, &c.CodeHash, &c.Attempts, &c.ExpiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return EmailChangeCode{}, ErrNotFound
	}
	return c, err
}

// RedeemEmailChange atomically checks the code and, on a match, moves the new
// address onto the account and marks it verified.
//
// Everything happens in one transaction with the code row locked, so two
// concurrent confirms cannot both spend the same code. A wrong guess increments
// attempts and burns the code once the cap is hit.
func (s *Store) RedeemEmailChange(ctx context.Context, userID, codeHash string) (User, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return User{}, err
	}
	defer tx.Rollback(ctx)

	var id, newEmail, storedHash string
	var attempts int
	err = tx.QueryRow(ctx,
		`SELECT id, new_email, code_hash, attempts FROM email_change_codes
		 WHERE user_id = $1 AND used_at IS NULL AND expires_at > now()
		 ORDER BY created_at DESC LIMIT 1
		 FOR UPDATE`, userID).Scan(&id, &newEmail, &storedHash, &attempts)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrEmailCodeInvalid
	}
	if err != nil {
		return User{}, err
	}

	if storedHash != codeHash {
		attempts++
		q := `UPDATE email_change_codes SET attempts = $2 WHERE id = $1`
		if attempts >= MaxEmailCodeAttempts {
			q = `UPDATE email_change_codes SET attempts = $2, used_at = now() WHERE id = $1`
		}
		if _, err = tx.Exec(ctx, q, id, attempts); err != nil {
			return User{}, err
		}
		if err = tx.Commit(ctx); err != nil {
			return User{}, err
		}
		return User{}, ErrEmailCodeInvalid
	}

	// Someone may have claimed the address between request and confirm.
	var taken bool
	if err = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE lower(email) = lower($1) AND id <> $2)`,
		newEmail, userID).Scan(&taken); err != nil {
		return User{}, err
	}
	if taken {
		return User{}, ErrEmailTaken
	}

	u, err := scanUser(tx.QueryRow(ctx,
		`UPDATE users SET email = $2, email_verified = true, updated_at = now()
		 WHERE id = $1 RETURNING `+userCols, userID, newEmail))
	if err != nil {
		return User{}, err
	}
	if _, err = tx.Exec(ctx, `UPDATE email_change_codes SET used_at = now() WHERE id = $1`, id); err != nil {
		return User{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return User{}, err
	}
	return u, nil
}
