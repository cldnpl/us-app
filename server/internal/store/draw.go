package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type DrawSubmission struct {
	ID        string
	RoundID   string
	UserID    string
	FilePath  string
	ThumbPath string
	CreatedAt time.Time
}

// UpsertDrawSubmission stores (or replaces) a partner's drawing for a round.
func (s *Store) UpsertDrawSubmission(ctx context.Context, roundID, userID, filePath, thumbPath string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO draw_submissions (round_id, user_id, file_path, thumb_path)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (round_id, user_id)
		 DO UPDATE SET file_path = EXCLUDED.file_path, thumb_path = EXCLUDED.thumb_path, created_at = now()`,
		roundID, userID, filePath, thumbPath)
	return err
}

// GetDrawSubmissions returns both partners' drawings for a round.
func (s *Store) GetDrawSubmissions(ctx context.Context, roundID string) ([]DrawSubmission, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, round_id, user_id, file_path, thumb_path, created_at
		 FROM draw_submissions WHERE round_id = $1`, roundID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []DrawSubmission
	for rows.Next() {
		var d DrawSubmission
		if err := rows.Scan(&d.ID, &d.RoundID, &d.UserID, &d.FilePath, &d.ThumbPath, &d.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// GetDrawSubmissionForUser fetches one partner's drawing in a round, if any.
func (s *Store) GetDrawSubmissionForUser(ctx context.Context, roundID, userID string) (DrawSubmission, error) {
	var d DrawSubmission
	err := s.pool.QueryRow(ctx,
		`SELECT id, round_id, user_id, file_path, thumb_path, created_at
		 FROM draw_submissions WHERE round_id = $1 AND user_id = $2`, roundID, userID).
		Scan(&d.ID, &d.RoundID, &d.UserID, &d.FilePath, &d.ThumbPath, &d.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return DrawSubmission{}, ErrNotFound
	}
	return d, err
}

// GetDrawSubmissionOwned returns a submission's file path plus the couple that
// owns its round, so a serve handler can enforce couple scoping in one query.
func (s *Store) GetDrawSubmissionOwned(ctx context.Context, id string) (filePath, coupleID string, err error) {
	err = s.pool.QueryRow(ctx,
		`SELECT s.file_path, g.couple_id
		 FROM draw_submissions s JOIN game_sessions g ON g.id = s.round_id
		 WHERE s.id = $1`, id).Scan(&filePath, &coupleID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", ErrNotFound
	}
	return filePath, coupleID, err
}
