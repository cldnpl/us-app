package store

import (
	"context"
	"time"
)

type QuestionAnswer struct {
	UserID    string
	Answer    string
	CreatedAt time.Time
}

func (s *Store) UpsertAnswer(ctx context.Context, coupleID string, day time.Time, userID, answer string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO question_answers (couple_id, day, user_id, answer) VALUES ($1, $2, $3, $4)
		 ON CONFLICT (couple_id, day, user_id) DO UPDATE SET answer = $4, created_at = now()`,
		coupleID, day, userID, answer)
	return err
}

func (s *Store) GetAnswers(ctx context.Context, coupleID string, day time.Time) ([]QuestionAnswer, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT user_id, answer, created_at FROM question_answers WHERE couple_id = $1 AND day = $2`,
		coupleID, day)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []QuestionAnswer
	for rows.Next() {
		var a QuestionAnswer
		if err := rows.Scan(&a.UserID, &a.Answer, &a.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}
