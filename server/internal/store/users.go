package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// User is the persistence model for an account (includes secret columns).
type User struct {
	ID           string
	Email        *string
	PasswordHash *string
	AppleUserID  *string
	DisplayName  string
	AvatarPath   *string
	Birthday     *time.Time
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type CreateUserParams struct {
	Email        *string
	PasswordHash *string
	AppleUserID  *string
	DisplayName  string
}

const userCols = `id, email, password_hash, apple_user_id, display_name, avatar_path, birthday, created_at, updated_at`

func scanUser(row pgx.Row) (User, error) {
	var u User
	err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &u.AppleUserID, &u.DisplayName,
		&u.AvatarPath, &u.Birthday, &u.CreatedAt, &u.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}

func (s *Store) CreateUser(ctx context.Context, p CreateUserParams) (User, error) {
	return scanUser(s.pool.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, apple_user_id, display_name)
		 VALUES ($1, $2, $3, $4)
		 RETURNING `+userCols,
		p.Email, p.PasswordHash, p.AppleUserID, p.DisplayName))
}

func (s *Store) GetUserByID(ctx context.Context, id string) (User, error) {
	return scanUser(s.pool.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE id = $1`, id))
}

func (s *Store) GetUserByEmail(ctx context.Context, email string) (User, error) {
	return scanUser(s.pool.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE email = $1`, email))
}

func (s *Store) GetUserByAppleID(ctx context.Context, appleID string) (User, error) {
	return scanUser(s.pool.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE apple_user_id = $1`, appleID))
}

// UpdateUserProfile updates only the non-nil fields (COALESCE keeps existing values).
func (s *Store) UpdateUserProfile(ctx context.Context, id string, displayName *string, birthday *time.Time) (User, error) {
	return scanUser(s.pool.QueryRow(ctx,
		`UPDATE users SET
		   display_name = COALESCE($2, display_name),
		   birthday     = COALESCE($3, birthday),
		   updated_at   = now()
		 WHERE id = $1
		 RETURNING `+userCols,
		id, displayName, birthday))
}
