-- +goose Up
-- Account-level settings that used to live only in the app's UserDefaults, so
-- they survive a reinstall and follow the account onto a new device.
--
-- has_cycle is NOT added here: 0013 already added it (nullable on purpose —
-- NULL means "never asked", which the app tells apart from an explicit yes/no)
-- and that migration is already applied in production. Re-adding it would fail
-- the whole file on boot. This one was numbered 0013 too on its branch; it had
-- to move to 0014, or goose would have seen version 13 as already applied and
-- silently skipped everything below.
ALTER TABLE users ADD COLUMN cycle_share_level text NOT NULL DEFAULT 'off';

-- Whether the address on the account has been confirmed by entering a code we
-- sent to it. Accounts created before this migration are grandfathered in as
-- unverified; nothing gates on it yet, it only marks addresses we have proved.
ALTER TABLE users ADD COLUMN email_verified boolean NOT NULL DEFAULT false;

-- One-time codes for changing the email on an account. Mirrors pairing_codes:
-- the raw code is never stored, only its SHA-256 hash, and a row is spent by
-- stamping used_at. attempts caps brute-force guessing of a live code.
CREATE TABLE email_change_codes (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    new_email  text NOT NULL,
    code_hash  text NOT NULL,
    attempts   integer NOT NULL DEFAULT 0,
    expires_at timestamptz NOT NULL,
    used_at    timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Lookup path for "the live code for this user".
CREATE INDEX email_change_codes_pending_idx
    ON email_change_codes (user_id, created_at DESC)
    WHERE used_at IS NULL;

-- +goose Down
-- has_cycle is not dropped here — it belongs to 0013, which owns rolling it back.
DROP TABLE email_change_codes;
ALTER TABLE users DROP COLUMN email_verified;
ALTER TABLE users DROP COLUMN cycle_share_level;
