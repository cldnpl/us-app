-- +goose Up
-- Draw Together submissions. Each drawing round reuses a game_sessions row
-- (game_type 'draw', state holds the shared prompt); this table stores each
-- partner's drawing for that round. Kept separate from the media table so
-- drawings never appear in the couple's gallery.
CREATE TABLE draw_submissions (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id   uuid NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_path  text NOT NULL,
    thumb_path text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (round_id, user_id)
);
CREATE INDEX idx_draw_submissions_round ON draw_submissions(round_id);

-- +goose Down
DROP TABLE IF EXISTS draw_submissions;
