-- +goose Up
-- Optional free-text "thoughts for the day" a user can choose to share along
-- with her phase (the "cycle + thoughts" sharing level).
ALTER TABLE cycle_shares ADD COLUMN note text;

-- +goose Down
ALTER TABLE cycle_shares DROP COLUMN note;
