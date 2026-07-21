-- +goose Up
-- Whether this user tracks a menstrual cycle. Stored server-side so the choice
-- survives re-login and reinstalls instead of resetting to "not set" — it used
-- to live only in the app's UserDefaults, which a reinstall wipes.
ALTER TABLE users ADD COLUMN has_cycle boolean;

-- +goose Down
ALTER TABLE users DROP COLUMN has_cycle;
