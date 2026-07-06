-- +goose Up
-- How this user refers to their partner (she/he/they). Stored server-side so it
-- survives re-login and reinstalls instead of being asked again.
ALTER TABLE users ADD COLUMN partner_pronoun text;

-- +goose Down
ALTER TABLE users DROP COLUMN partner_pronoun;
