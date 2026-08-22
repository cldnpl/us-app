-- +goose Up
-- When we last sent a given kind of notification to a couple.
--
-- Two jobs: it coalesces bursts (saving a diary entry with five photos is one
-- notification, not six), and it makes the daily Question of the Day nudge fire
-- exactly once a day even across a restart or a second server instance — the
-- claim is an atomic conditional upsert, so only one caller wins the day.
CREATE TABLE IF NOT EXISTS notification_marks (
    couple_id UUID        NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    kind      TEXT        NOT NULL,
    sent_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (couple_id, kind)
);

-- +goose Down
DROP TABLE IF EXISTS notification_marks;
