-- +goose Up
-- A couple can only be drawing or hunting in one active round at a time.
-- Preserve the most recent round if old builds ever created duplicates.
WITH ranked AS (
    SELECT id,
           row_number() OVER (
               PARTITION BY couple_id, game_type
               ORDER BY created_at DESC, id DESC
           ) AS position
    FROM game_sessions
    WHERE game_type IN ('draw', 'snap') AND status = 'active'
)
UPDATE game_sessions AS games
SET status = 'finished', turn_user_id = NULL, updated_at = now()
FROM ranked
WHERE games.id = ranked.id AND ranked.position > 1;

CREATE UNIQUE INDEX idx_one_active_draw_or_snap_per_couple
ON game_sessions (couple_id, game_type)
WHERE status = 'active' AND game_type IN ('draw', 'snap');

-- +goose Down
DROP INDEX IF EXISTS idx_one_active_draw_or_snap_per_couple;
