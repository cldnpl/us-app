-- +goose Up
-- One opt-in cycle summary per user. Deliberately minimal: only a coarse phase
-- and (optionally) a day count — never raw symptoms — so the partner gets a
-- gentle heads-up without this table ever holding sensitive health detail.
CREATE TABLE cycle_shares (
    user_id        uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    phase          text NOT NULL,
    cycle_day      integer,
    period_in_days integer,
    updated_at     timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE IF EXISTS cycle_shares;
