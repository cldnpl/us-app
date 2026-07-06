-- +goose Up
CREATE TABLE journal_entries (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id  uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    author_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entry_date date NOT NULL,
    body       text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (couple_id, author_id, entry_date) -- one entry per author per day (upsert)
);
CREATE INDEX idx_journal_couple_date ON journal_entries(couple_id, entry_date DESC, created_at DESC);

-- Journal photos reuse the media pipeline (SaveImage/thumbnail/serve); link them
-- to the owning entry so they never leak into the standalone gallery feed.
ALTER TABLE media ADD COLUMN journal_entry_id uuid REFERENCES journal_entries(id) ON DELETE CASCADE;
CREATE INDEX idx_media_journal ON media(journal_entry_id) WHERE journal_entry_id IS NOT NULL;

-- +goose Down
ALTER TABLE media DROP COLUMN IF EXISTS journal_entry_id;
DROP TABLE IF EXISTS journal_entries;
