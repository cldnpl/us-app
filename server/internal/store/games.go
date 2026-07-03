package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type GameSession struct {
	ID         string
	CoupleID   string
	GameType   string
	State      []byte
	TurnUserID *string
	Status     string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

const gameCols = `id, couple_id, game_type, state, turn_user_id, status, created_at, updated_at`

func scanGame(row pgx.Row) (GameSession, error) {
	var g GameSession
	err := row.Scan(&g.ID, &g.CoupleID, &g.GameType, &g.State, &g.TurnUserID, &g.Status, &g.CreatedAt, &g.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return GameSession{}, ErrNotFound
	}
	return g, err
}

func (s *Store) CreateGame(ctx context.Context, coupleID, gameType string, state []byte, turnUserID string) (GameSession, error) {
	return scanGame(s.pool.QueryRow(ctx,
		`INSERT INTO game_sessions (couple_id, game_type, state, turn_user_id, status)
		 VALUES ($1, $2, $3, $4, 'active') RETURNING `+gameCols,
		coupleID, gameType, state, turnUserID))
}

// GetLatestGame returns the most recent game of a type regardless of status, so
// a finished board (with its winner) stays visible until a new game is started.
func (s *Store) GetLatestGame(ctx context.Context, coupleID, gameType string) (GameSession, error) {
	return scanGame(s.pool.QueryRow(ctx,
		`SELECT `+gameCols+` FROM game_sessions
		 WHERE couple_id = $1 AND game_type = $2
		 ORDER BY created_at DESC LIMIT 1`, coupleID, gameType))
}

func (s *Store) UpdateGame(ctx context.Context, id string, state []byte, turnUserID *string, status string) (GameSession, error) {
	return scanGame(s.pool.QueryRow(ctx,
		`UPDATE game_sessions SET state = $2, turn_user_id = $3, status = $4, updated_at = now()
		 WHERE id = $1 RETURNING `+gameCols, id, state, turnUserID, status))
}

func (s *Store) FinishActiveGames(ctx context.Context, coupleID, gameType string) error {
	_, err := s.pool.Exec(ctx,
		`UPDATE game_sessions SET status = 'finished', turn_user_id = NULL, updated_at = now()
		 WHERE couple_id = $1 AND game_type = $2 AND status = 'active'`, coupleID, gameType)
	return err
}
