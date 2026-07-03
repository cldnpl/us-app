-- +goose Up
CREATE TABLE locations (
    user_id      uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    lat          double precision NOT NULL,
    lng          double precision NOT NULL,
    accuracy     double precision,
    sharing_mode text NOT NULL DEFAULT 'live',
    expires_at   timestamptz,
    updated_at   timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE IF EXISTS locations;
