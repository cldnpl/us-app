package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type Couple struct {
	ID        string
	StartDate *time.Time
	Status    string
	CreatedAt time.Time
}

const coupleCols = `id, start_date, status, created_at`

func scanCouple(row pgx.Row) (Couple, error) {
	var c Couple
	err := row.Scan(&c.ID, &c.StartDate, &c.Status, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Couple{}, ErrNotFound
	}
	return c, err
}

func (s *Store) GetCoupleForUser(ctx context.Context, userID string) (Couple, error) {
	return scanCouple(s.pool.QueryRow(ctx,
		`SELECT c.id, c.start_date, c.status, c.created_at
		 FROM couples c JOIN couple_members m ON m.couple_id = c.id
		 WHERE m.user_id = $1`, userID))
}

func (s *Store) GetPartner(ctx context.Context, coupleID, userID string) (User, error) {
	return scanUser(s.pool.QueryRow(ctx,
		`SELECT `+userCols+` FROM users
		 JOIN couple_members m ON m.user_id = users.id
		 WHERE m.couple_id = $1 AND m.user_id <> $2
		 LIMIT 1`, coupleID, userID))
}

func (s *Store) GetCoupleMembers(ctx context.Context, coupleID string) ([]User, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+userCols+` FROM users
		 JOIN couple_members m ON m.user_id = users.id
		 WHERE m.couple_id = $1 ORDER BY m.joined_at`, coupleID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []User
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

func (s *Store) DeleteCouple(ctx context.Context, coupleID string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM couples WHERE id = $1`, coupleID)
	return err
}

func (s *Store) UpdateCoupleStartDate(ctx context.Context, coupleID string, startDate *time.Time) (Couple, error) {
	return scanCouple(s.pool.QueryRow(ctx,
		`UPDATE couples SET start_date = $2 WHERE id = $1 RETURNING `+coupleCols,
		coupleID, startDate))
}
