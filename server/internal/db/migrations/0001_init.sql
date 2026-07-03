-- +goose Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email         text UNIQUE,
    password_hash text,
    apple_user_id text UNIQUE,
    display_name  text NOT NULL DEFAULT '',
    avatar_path   text,
    birthday      date,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash);

CREATE TABLE couples (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    start_date date,
    status     text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE couple_members (
    couple_id uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    user_id   uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    role      text NOT NULL DEFAULT 'member',
    joined_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (couple_id, user_id)
);

CREATE TABLE pairing_codes (
    code            text PRIMARY KEY,
    inviter_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at      timestamptz NOT NULL,
    used_at         timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_pairing_codes_inviter ON pairing_codes(inviter_user_id);

CREATE TABLE devices (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    apns_token  text NOT NULL,
    platform    text NOT NULL DEFAULT 'ios',
    environment text NOT NULL DEFAULT 'sandbox',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, apns_token)
);
CREATE INDEX idx_devices_user ON devices(user_id);

CREATE TABLE miss_you_events (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id  uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    sender_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind       text NOT NULL DEFAULT 'miss_you',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_miss_you_couple ON miss_you_events(couple_id, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS miss_you_events;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS pairing_codes;
DROP TABLE IF EXISTS couple_members;
DROP TABLE IF EXISTS couples;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
