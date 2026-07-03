package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

func (s *Store) CreateRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, tokenHash, expiresAt)
	return err
}

// GetActiveRefreshToken returns (tokenID, userID) for a valid, non-revoked, unexpired token.
func (s *Store) GetActiveRefreshToken(ctx context.Context, tokenHash string) (tokenID, userID string, err error) {
	err = s.pool.QueryRow(ctx,
		`SELECT id, user_id FROM refresh_tokens
		 WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()`,
		tokenHash).Scan(&tokenID, &userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", ErrNotFound
	}
	return tokenID, userID, err
}

func (s *Store) RevokeRefreshToken(ctx context.Context, id string) error {
	_, err := s.pool.Exec(ctx, `UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1`, id)
	return err
}

func (s *Store) RevokeRefreshTokenByHash(ctx context.Context, tokenHash string) error {
	_, err := s.pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL`,
		tokenHash)
	return err
}
