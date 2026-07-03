-- +goose Up
CREATE TABLE media (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id       uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    uploader_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind            text NOT NULL DEFAULT 'photo',
    file_path       text NOT NULL,
    thumb_path      text,
    caption         text,
    content_type    text,
    size_bytes      bigint NOT NULL DEFAULT 0,
    is_widget_photo boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_media_couple ON media(couple_id, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS media;
