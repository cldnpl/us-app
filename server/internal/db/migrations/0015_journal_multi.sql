-- +goose Up
-- Allow any number of diary entries per author per day; edits now go through
-- PUT /journal/{id} instead of the old same-day upsert.
ALTER TABLE journal_entries DROP CONSTRAINT IF EXISTS journal_entries_couple_id_author_id_entry_date_key;

-- +goose Down
ALTER TABLE journal_entries ADD CONSTRAINT journal_entries_couple_id_author_id_entry_date_key UNIQUE (couple_id, author_id, entry_date);
