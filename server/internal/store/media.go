package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type Media struct {
	ID            string
	CoupleID      string
	UploaderID    string
	Kind          string
	FilePath      string
	ThumbPath     *string
	Caption       *string
	ContentType    *string
	SizeBytes      int64
	IsWidgetPhoto  bool
	JournalEntryID *string
	CreatedAt      time.Time
}

type CreateMediaParams struct {
	ID             string
	CoupleID       string
	UploaderID     string
	Kind           string
	FilePath       string
	ThumbPath      string
	Caption        *string
	ContentType    string
	SizeBytes      int64
	JournalEntryID *string // set when the photo belongs to a journal entry
}

const mediaCols = `id, couple_id, uploader_id, kind, file_path, thumb_path, caption, content_type, size_bytes, is_widget_photo, journal_entry_id, created_at`

func scanMedia(row pgx.Row) (Media, error) {
	var m Media
	err := row.Scan(&m.ID, &m.CoupleID, &m.UploaderID, &m.Kind, &m.FilePath, &m.ThumbPath,
		&m.Caption, &m.ContentType, &m.SizeBytes, &m.IsWidgetPhoto, &m.JournalEntryID, &m.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Media{}, ErrNotFound
	}
	return m, err
}

func (s *Store) CreateMedia(ctx context.Context, p CreateMediaParams) (Media, error) {
	return scanMedia(s.pool.QueryRow(ctx,
		`INSERT INTO media (id, couple_id, uploader_id, kind, file_path, thumb_path, caption, content_type, size_bytes, journal_entry_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 RETURNING `+mediaCols,
		p.ID, p.CoupleID, p.UploaderID, p.Kind, p.FilePath, p.ThumbPath, p.Caption, p.ContentType, p.SizeBytes, p.JournalEntryID))
}

func (s *Store) ListMedia(ctx context.Context, coupleID string, limit, offset int) ([]Media, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+mediaCols+` FROM media
		 WHERE couple_id = $1 AND journal_entry_id IS NULL
		 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		coupleID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Media
	for rows.Next() {
		m, err := scanMedia(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// ListMediaByUploader returns every media row a user uploaded, so account
// deletion can clean their files off disk before the DB rows cascade away.
func (s *Store) ListMediaByUploader(ctx context.Context, uploaderID string) ([]Media, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+mediaCols+` FROM media WHERE uploader_id = $1`, uploaderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Media
	for rows.Next() {
		m, err := scanMedia(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (s *Store) GetMedia(ctx context.Context, id string) (Media, error) {
	return scanMedia(s.pool.QueryRow(ctx, `SELECT `+mediaCols+` FROM media WHERE id = $1`, id))
}

func (s *Store) DeleteMedia(ctx context.Context, id string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM media WHERE id = $1`, id)
	return err
}

func (s *Store) CountMedia(ctx context.Context, coupleID string) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx, `SELECT count(*) FROM media WHERE couple_id = $1`, coupleID).Scan(&n)
	return n, err
}

func (s *Store) StorageUsed(ctx context.Context, coupleID string) (int64, error) {
	var total int64
	err := s.pool.QueryRow(ctx, `SELECT COALESCE(SUM(size_bytes), 0) FROM media WHERE couple_id = $1`, coupleID).Scan(&total)
	return total, err
}
