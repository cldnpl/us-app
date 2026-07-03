package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type Milestone struct {
	ID        string
	CoupleID  string
	Title     string
	Date      time.Time
	Kind      string
	CreatedAt time.Time
}

type Reunion struct {
	ID         string
	CoupleID   string
	Title      string
	TargetDate time.Time
	CreatedAt  time.Time
}

func (s *Store) CreateMilestone(ctx context.Context, coupleID, title string, date time.Time, kind string) (Milestone, error) {
	var m Milestone
	err := s.pool.QueryRow(ctx,
		`INSERT INTO milestones (couple_id, title, date, kind) VALUES ($1, $2, $3, $4)
		 RETURNING id, couple_id, title, date, kind, created_at`,
		coupleID, title, date, kind).Scan(&m.ID, &m.CoupleID, &m.Title, &m.Date, &m.Kind, &m.CreatedAt)
	return m, err
}

func (s *Store) ListMilestones(ctx context.Context, coupleID string) ([]Milestone, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, couple_id, title, date, kind, created_at FROM milestones WHERE couple_id = $1 ORDER BY date`, coupleID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Milestone
	for rows.Next() {
		var m Milestone
		if err := rows.Scan(&m.ID, &m.CoupleID, &m.Title, &m.Date, &m.Kind, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (s *Store) GetMilestone(ctx context.Context, id string) (Milestone, error) {
	var m Milestone
	err := s.pool.QueryRow(ctx,
		`SELECT id, couple_id, title, date, kind, created_at FROM milestones WHERE id = $1`, id).
		Scan(&m.ID, &m.CoupleID, &m.Title, &m.Date, &m.Kind, &m.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Milestone{}, ErrNotFound
	}
	return m, err
}

func (s *Store) DeleteMilestone(ctx context.Context, id string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM milestones WHERE id = $1`, id)
	return err
}

func (s *Store) CreateReunion(ctx context.Context, coupleID, title string, target time.Time) (Reunion, error) {
	var r Reunion
	err := s.pool.QueryRow(ctx,
		`INSERT INTO reunions (couple_id, title, target_date) VALUES ($1, $2, $3)
		 RETURNING id, couple_id, title, target_date, created_at`,
		coupleID, title, target).Scan(&r.ID, &r.CoupleID, &r.Title, &r.TargetDate, &r.CreatedAt)
	return r, err
}

func (s *Store) ListReunions(ctx context.Context, coupleID string) ([]Reunion, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, couple_id, title, target_date, created_at FROM reunions WHERE couple_id = $1 ORDER BY target_date`, coupleID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Reunion
	for rows.Next() {
		var r Reunion
		if err := rows.Scan(&r.ID, &r.CoupleID, &r.Title, &r.TargetDate, &r.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) GetReunion(ctx context.Context, id string) (Reunion, error) {
	var r Reunion
	err := s.pool.QueryRow(ctx,
		`SELECT id, couple_id, title, target_date, created_at FROM reunions WHERE id = $1`, id).
		Scan(&r.ID, &r.CoupleID, &r.Title, &r.TargetDate, &r.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Reunion{}, ErrNotFound
	}
	return r, err
}

func (s *Store) DeleteReunion(ctx context.Context, id string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM reunions WHERE id = $1`, id)
	return err
}
