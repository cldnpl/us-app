package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// JournalEntry is one partner's diary entry for a single day. There is at most
// one entry per (couple, author, date); the client groups both partners'
// entries under a shared day card.
type JournalEntry struct {
	ID        string
	CoupleID  string
	AuthorID  string
	Date      time.Time
	Body      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

const journalCols = `id, couple_id, author_id, entry_date, body, created_at, updated_at`

func scanJournalEntry(row pgx.Row) (JournalEntry, error) {
	var e JournalEntry
	err := row.Scan(&e.ID, &e.CoupleID, &e.AuthorID, &e.Date, &e.Body, &e.CreatedAt, &e.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return JournalEntry{}, ErrNotFound
	}
	return e, err
}

// UpsertEntry creates the author's entry for the given day, or replaces its body
// if one already exists (one entry per author per day).
func (s *Store) UpsertEntry(ctx context.Context, coupleID, authorID string, date time.Time, body string) (JournalEntry, error) {
	return scanJournalEntry(s.pool.QueryRow(ctx,
		`INSERT INTO journal_entries (couple_id, author_id, entry_date, body)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (couple_id, author_id, entry_date)
		 DO UPDATE SET body = EXCLUDED.body, updated_at = now()
		 RETURNING `+journalCols,
		coupleID, authorID, date, body))
}

// ListEntries returns every entry for the couple, most recent day first.
func (s *Store) ListEntries(ctx context.Context, coupleID string) ([]JournalEntry, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+journalCols+` FROM journal_entries WHERE couple_id = $1
		 ORDER BY entry_date DESC, created_at DESC`, coupleID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []JournalEntry
	for rows.Next() {
		e, err := scanJournalEntry(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) GetEntry(ctx context.Context, id string) (JournalEntry, error) {
	return scanJournalEntry(s.pool.QueryRow(ctx, `SELECT `+journalCols+` FROM journal_entries WHERE id = $1`, id))
}

func (s *Store) DeleteEntry(ctx context.Context, id string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM journal_entries WHERE id = $1`, id)
	return err
}

// ListJournalMedia returns every journal photo for the couple (newest first) so
// the handler can group them onto their entries in one pass.
func (s *Store) ListJournalMedia(ctx context.Context, coupleID string) ([]Media, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+mediaCols+` FROM media
		 WHERE couple_id = $1 AND journal_entry_id IS NOT NULL
		 ORDER BY created_at DESC`, coupleID)
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

// ListMediaForEntry returns the photos attached to a single entry (used to
// remove the underlying files before deleting the entry).
func (s *Store) ListMediaForEntry(ctx context.Context, entryID string) ([]Media, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+mediaCols+` FROM media WHERE journal_entry_id = $1 ORDER BY created_at`, entryID)
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
