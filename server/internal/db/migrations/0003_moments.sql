-- +goose Up
CREATE TABLE milestones (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id  uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    title      text NOT NULL,
    date       date NOT NULL,
    kind       text NOT NULL DEFAULT 'milestone',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_milestones_couple ON milestones(couple_id, date);

CREATE TABLE reunions (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id   uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    title       text NOT NULL,
    target_date date NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_reunions_couple ON reunions(couple_id, target_date);

-- +goose Down
DROP TABLE IF EXISTS reunions;
DROP TABLE IF EXISTS milestones;
