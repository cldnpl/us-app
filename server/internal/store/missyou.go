package store

import (
	"context"
	"time"
)

type MissYou struct {
	ID        string
	SenderID  string
	Kind      string
	CreatedAt time.Time
}

func (s *Store) CreateMissYou(ctx context.Context, coupleID, senderID, kind string) (MissYou, error) {
	var m MissYou
	err := s.pool.QueryRow(ctx,
		`INSERT INTO miss_you_events (couple_id, sender_id, kind)
		 VALUES ($1, $2, $3)
		 RETURNING id, sender_id, kind, created_at`,
		coupleID, senderID, kind).Scan(&m.ID, &m.SenderID, &m.Kind, &m.CreatedAt)
	return m, err
}

func (s *Store) ListMissYou(ctx context.Context, coupleID string, limit int) ([]MissYou, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, sender_id, kind, created_at FROM miss_you_events
		 WHERE couple_id = $1 ORDER BY created_at DESC LIMIT $2`, coupleID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []MissYou
	for rows.Next() {
		var m MissYou
		if err := rows.Scan(&m.ID, &m.SenderID, &m.Kind, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}
