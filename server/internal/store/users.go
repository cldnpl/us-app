package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// ErrEmailTaken is returned when an address is already on another account.
var ErrEmailTaken = errors.New("email already in use")

// User is the persistence model for an account (includes secret columns).
type User struct {
	ID             string
	Email          *string
	PasswordHash   *string
	AppleUserID    *string
	DisplayName    string
	AvatarPath     *string
	Birthday       *time.Time
	PartnerPronoun *string
	EmailVerified  bool
	// HasCycle is nil when the user has never been asked.
	HasCycle        *bool
	CycleShareLevel string
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

type CreateUserParams struct {
	Email        *string
	PasswordHash *string
	AppleUserID  *string
	DisplayName  string
}

const userCols = `id, email, password_hash, apple_user_id, display_name, avatar_path, birthday, partner_pronoun, email_verified, has_cycle, cycle_share_level, created_at, updated_at`

func scanUser(row pgx.Row) (User, error) {
	var u User
	err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &u.AppleUserID, &u.DisplayName,
		&u.AvatarPath, &u.Birthday, &u.PartnerPronoun, &u.EmailVerified,
		&u.HasCycle, &u.CycleShareLevel, &u.CreatedAt, &u.UpdatedAt)
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

// UpdateUserProfileParams carries a partial profile update: every field is a
// pointer, and only the non-nil ones are written.
type UpdateUserProfileParams struct {
	DisplayName     *string
	Birthday        *time.Time
	PartnerPronoun  *string
	HasCycle        *bool
	CycleShareLevel *string
}

// UpdateUserProfile updates only the non-nil fields (COALESCE keeps existing values).
func (s *Store) UpdateUserProfile(ctx context.Context, id string, p UpdateUserProfileParams) (User, error) {
	return scanUser(s.pool.QueryRow(ctx,
		`UPDATE users SET
		   display_name      = COALESCE($2, display_name),
		   birthday          = COALESCE($3, birthday),
		   partner_pronoun   = COALESCE($4, partner_pronoun),
		   has_cycle         = COALESCE($5, has_cycle),
		   cycle_share_level = COALESCE($6, cycle_share_level),
		   updated_at        = now()
		 WHERE id = $1
		 RETURNING `+userCols,
		id, p.DisplayName, p.Birthday, p.PartnerPronoun, p.HasCycle, p.CycleShareLevel))
}

// EmailInUse reports whether an address belongs to an account other than the
// given one. Compared case-insensitively, matching how addresses are stored.
func (s *Store) EmailInUse(ctx context.Context, email, excludeUserID string) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE lower(email) = lower($1) AND id <> $2)`,
		email, excludeUserID).Scan(&exists)
	return exists, err
}
