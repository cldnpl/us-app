package httpapi

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

func toDomainJournalEntry(e store.JournalEntry, photos []store.Media) domain.JournalEntry {
	out := domain.JournalEntry{
		ID:        e.ID,
		AuthorID:  e.AuthorID,
		Date:      e.Date,
		Body:      e.Body,
		Photos:    make([]domain.Media, 0, len(photos)),
		CreatedAt: e.CreatedAt,
		UpdatedAt: e.UpdatedAt,
	}
	for _, m := range photos {
		out.Photos = append(out.Photos, toDomainMedia(m))
	}
	return out
}

func (d Deps) handleListJournal(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	entries, err := d.Store.ListEntries(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "journal: list", err)
		return
	}
	media, err := d.Store.ListJournalMedia(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "journal: media", err)
		return
	}
	// Group photos onto their entries in one pass (newest first already).
	byEntry := make(map[string][]store.Media, len(entries))
	for _, m := range media {
		if m.JournalEntryID != nil {
			byEntry[*m.JournalEntryID] = append(byEntry[*m.JournalEntryID], m)
		}
	}
	out := make([]domain.JournalEntry, len(entries))
	for i, e := range entries {
		out[i] = toDomainJournalEntry(e, byEntry[e.ID])
	}
	writeJSON(w, http.StatusOK, map[string]any{"entries": out})
}

type journalEntryRequest struct {
	Date string `json:"date"` // YYYY-MM-DD
	Body string `json:"body"`
}

func (d Deps) handleCreateJournalEntry(w http.ResponseWriter, r *http.Request) {
	c, userID, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	var req journalEntryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_date", "date must be YYYY-MM-DD")
		return
	}
	e, err := d.Store.UpsertEntry(r.Context(), c.ID, userID, date, strings.TrimSpace(req.Body))
	if err != nil {
		d.serverError(w, "journal: upsert", err)
		return
	}
	writeJSON(w, http.StatusCreated, toDomainJournalEntry(e, nil))
}

// entryForAuthor loads an entry and verifies the caller both belongs to the
// owning couple and is its author (only the author edits their own entry).
func (d Deps) entryForAuthor(w http.ResponseWriter, r *http.Request) (store.JournalEntry, string, bool) {
	c, userID, ok := d.coupleForRequest(w, r)
	if !ok {
		return store.JournalEntry{}, "", false
	}
	e, err := d.Store.GetEntry(r.Context(), chi.URLParam(r, "id"))
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not_found", "not found")
		return store.JournalEntry{}, "", false
	} else if err != nil {
		d.serverError(w, "journal: get", err)
		return store.JournalEntry{}, "", false
	}
	if e.CoupleID != c.ID || e.AuthorID != userID {
		writeError(w, http.StatusForbidden, "forbidden", "not allowed")
		return store.JournalEntry{}, "", false
	}
	return e, userID, true
}

func (d Deps) handleUploadJournalPhoto(w http.ResponseWriter, r *http.Request) {
	e, userID, ok := d.entryForAuthor(w, r)
	if !ok {
		return
	}
	if !d.isPremium(e.CoupleID) {
		if n, _ := d.Store.CountMedia(r.Context(), e.CoupleID); n >= freePhotoCap {
			writeError(w, http.StatusPaymentRequired, "limit_reached",
				"Free plan holds 100 photos — upgrade to Premium for unlimited")
			return
		}
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(maxUploadBytes + (1 << 20)); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_upload", "could not read the upload")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing_file", "a photo is required")
		return
	}
	defer file.Close()

	id := uuid.NewString()
	fullRel, thumbRel, size, err := d.Media.SaveImage(e.CoupleID, id, file)
	if err != nil {
		d.Logger.Error("journal: save image failed", "err", err)
		writeError(w, http.StatusBadRequest, "bad_image", "could not process that image")
		return
	}
	entryID := e.ID
	m, err := d.Store.CreateMedia(r.Context(), store.CreateMediaParams{
		ID: id, CoupleID: e.CoupleID, UploaderID: userID, Kind: "photo",
		FilePath: fullRel, ThumbPath: thumbRel,
		ContentType: "image/jpeg", SizeBytes: size, JournalEntryID: &entryID,
	})
	if err != nil {
		d.Media.Remove(fullRel, thumbRel)
		d.serverError(w, "journal: create media", err)
		return
	}

	d.sendPartnerPush(r.Context(), e.CoupleID, userID, func(name string) push.Notification {
		return push.Notification{Title: "📔", Body: name + " added to your journal", Data: map[string]string{"type": "journal_photo"}}
	})

	writeJSON(w, http.StatusCreated, toDomainMedia(m))
}

func (d Deps) handleDeleteJournalEntry(w http.ResponseWriter, r *http.Request) {
	e, _, ok := d.entryForAuthor(w, r)
	if !ok {
		return
	}
	// Remove the underlying photo files first; the media rows themselves are
	// cleared by the ON DELETE CASCADE when the entry is deleted.
	photos, err := d.Store.ListMediaForEntry(r.Context(), e.ID)
	if err != nil {
		d.serverError(w, "journal: entry media", err)
		return
	}
	for _, m := range photos {
		thumb := ""
		if m.ThumbPath != nil {
			thumb = *m.ThumbPath
		}
		d.Media.Remove(m.FilePath, thumb)
	}
	if err := d.Store.DeleteEntry(r.Context(), e.ID); err != nil {
		d.serverError(w, "journal: delete", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
