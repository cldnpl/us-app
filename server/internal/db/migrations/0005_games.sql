-- +goose Up
CREATE TABLE game_sessions (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id    uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    game_type    text NOT NULL,
    state        jsonb NOT NULL DEFAULT '{}'::jsonb,
    turn_user_id uuid,
    status       text NOT NULL DEFAULT 'active',
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_games_couple ON game_sessions(couple_id, game_type, status);

CREATE TABLE question_answers (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id  uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    day        date NOT NULL,
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answer     text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (couple_id, day, user_id)
);

-- +goose Down
DROP TABLE IF EXISTS question_answers;
DROP TABLE IF EXISTS game_sessions;
