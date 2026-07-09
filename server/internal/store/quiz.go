package store

import "context"

type QuizAnswer struct {
	QuestionID string
	UserID     string
	Answer     string
}

// QuizAnswerKey identifies one answered question by one user, used to compute
// per-user quiz completion / category progress without loading answer text.
type QuizAnswerKey struct {
	QuizID     string
	QuestionID string
	UserID     string
}

func (s *Store) UpsertQuizAnswer(ctx context.Context, coupleID, quizID, questionID, userID, answer string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO quiz_answers (couple_id, quiz_id, question_id, user_id, answer)
		 VALUES ($1, $2, $3, $4, $5)
		 ON CONFLICT (couple_id, quiz_id, question_id, user_id)
		 DO UPDATE SET answer = $5, created_at = now()`,
		coupleID, quizID, questionID, userID, answer)
	return err
}

// GetQuizAnswers returns every answer both partners have given for one quiz.
func (s *Store) GetQuizAnswers(ctx context.Context, coupleID, quizID string) ([]QuizAnswer, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT question_id, user_id, answer FROM quiz_answers
		 WHERE couple_id = $1 AND quiz_id = $2`, coupleID, quizID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []QuizAnswer
	for rows.Next() {
		var a QuizAnswer
		if err := rows.Scan(&a.QuestionID, &a.UserID, &a.Answer); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// GetQuizAnswerKeys returns (quiz, question, user) tuples for the whole couple,
// so callers can compute progress against the catalog in one round-trip.
func (s *Store) GetQuizAnswerKeys(ctx context.Context, coupleID string) ([]QuizAnswerKey, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT quiz_id, question_id, user_id FROM quiz_answers WHERE couple_id = $1`, coupleID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []QuizAnswerKey
	for rows.Next() {
		var k QuizAnswerKey
		if err := rows.Scan(&k.QuizID, &k.QuestionID, &k.UserID); err != nil {
			return nil, err
		}
		out = append(out, k)
	}
	return out, rows.Err()
}
