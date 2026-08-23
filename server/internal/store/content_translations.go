package store

import "context"

// ContentTranslation is one translated field of one catalog item — see
// migration 0018_content_translations.sql for what ContentType/Field values
// look like.
type ContentTranslation struct {
	ContentType string
	ContentID   string
	Field       string
	Lang        string
	Value       string
}

// UpsertContentTranslation writes or updates one translated field. Used by
// cmd/translate; safe to rerun (ON CONFLICT DO UPDATE), so an interrupted
// batch run can resume without re-spending on already-translated rows.
func (s *Store) UpsertContentTranslation(ctx context.Context, t ContentTranslation) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO content_translations (content_type, content_id, field, lang, value)
		 VALUES ($1, $2, $3, $4, $5)
		 ON CONFLICT (content_type, content_id, field, lang)
		 DO UPDATE SET value = $5, updated_at = now()`,
		t.ContentType, t.ContentID, t.Field, t.Lang, t.Value)
	return err
}

// AllContentTranslations loads the entire table, for the boot-time precompute
// of per-language catalog copies (internal/http). At this content's scale —
// a few thousand rows across every language — one full load is simpler and
// cheaper than querying per-request.
func (s *Store) AllContentTranslations(ctx context.Context) ([]ContentTranslation, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT content_type, content_id, field, lang, value FROM content_translations`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ContentTranslation
	for rows.Next() {
		var t ContentTranslation
		if err := rows.Scan(&t.ContentType, &t.ContentID, &t.Field, &t.Lang, &t.Value); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}
