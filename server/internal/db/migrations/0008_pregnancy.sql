-- +goose Up
-- One opt-in pregnancy share per user. We store only the due date; the week,
-- trimester, and countdown are derived on the client — nothing sensitive kept.
CREATE TABLE pregnancy_shares (
    user_id    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    due_date   date NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE IF EXISTS pregnancy_shares;
