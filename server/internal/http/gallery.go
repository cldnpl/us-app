package httpapi

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

const (
	maxUploadBytes = 15 << 20 // 15 MB per photo
	freePhotoCap   = 100
)

func toDomainMedia(m store.Media) domain.Media {
	return domain.Media{
		ID:         m.ID,
		Kind:       m.Kind,
		Caption:    m.Caption,
		UploaderID: m.UploaderID,
		FileURL:    "/v1/media/" + m.ID + "/file",
		ThumbURL:   "/v1/media/" + m.ID + "/thumb",
		CreatedAt:  m.CreatedAt,
	}
}

// isPremium reports whether the couple has an active subscription.
// TODO: read from the entitlements table once StoreKit is wired.
func (d Deps) isPremium(_ string) bool { return false }

func (d Deps) handleUploadMedia(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return
	} else if err != nil {
		d.serverError(w, "media: couple", err)
		return
	}

	if !d.isPremium(c.ID) {
		if n, _ := d.Store.CountMedia(r.Context(), c.ID); n >= freePhotoCap {
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
	fullRel, thumbRel, size, err := d.Media.SaveImage(c.ID, id, file)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_image", "could not process that image")
		return
	}

	var caption *string
	if v := r.FormValue("caption"); v != "" {
		caption = &v
	}
	m, err := d.Store.CreateMedia(r.Context(), store.CreateMediaParams{
		ID: id, CoupleID: c.ID, UploaderID: userID, Kind: "photo",
		FilePath: fullRel, ThumbPath: thumbRel, Caption: caption,
		ContentType: "image/jpeg", SizeBytes: size,
	})
	if err != nil {
		d.Media.Remove(fullRel, thumbRel)
		d.serverError(w, "media: create", err)
		return
	}

	// Notify the partner that a new photo arrived.
	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{Title: "📸", Body: name + " added a photo", Data: map[string]string{"type": "new_photo"}}
	})

	writeJSON(w, http.StatusCreated, toDomainMedia(m))
}

func (d Deps) handleListMedia(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return
	} else if err != nil {
		d.serverError(w, "media: couple", err)
		return
	}
	items, err := d.Store.ListMedia(r.Context(), c.ID, 100, 0)
	if err != nil {
		d.serverError(w, "media: list", err)
		return
	}
	out := make([]domain.Media, len(items))
	for i, m := range items {
		out[i] = toDomainMedia(m)
	}
	used, _ := d.Store.StorageUsed(r.Context(), c.ID)
	writeJSON(w, http.StatusOK, map[string]any{"media": out, "count": len(out), "storageUsed": used})
}

// handleServeMedia streams the full image or thumbnail after verifying the
// requester belongs to the owning couple.
func (d Deps) handleServeMedia(thumb bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := d.authedUser(w, r)
		if !ok {
			return
		}
		m, err := d.Store.GetMedia(r.Context(), chi.URLParam(r, "id"))
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "not_found", "not found")
			return
		} else if err != nil {
			d.serverError(w, "media: get", err)
			return
		}
		c, err := d.Store.GetCoupleForUser(r.Context(), userID)
		if err != nil || c.ID != m.CoupleID {
			writeError(w, http.StatusForbidden, "forbidden", "not allowed")
			return
		}
		rel := m.FilePath
		if thumb && m.ThumbPath != nil {
			rel = *m.ThumbPath
		}
		w.Header().Set("Cache-Control", "private, max-age=86400")
		http.ServeFile(w, r, d.Media.Abs(rel))
	}
}

func (d Deps) handleDeleteMedia(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	m, err := d.Store.GetMedia(r.Context(), chi.URLParam(r, "id"))
	if errors.Is(err, store.ErrNotFound) {
		w.WriteHeader(http.StatusNoContent)
		return
	} else if err != nil {
		d.serverError(w, "media: get", err)
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if err != nil || c.ID != m.CoupleID {
		writeError(w, http.StatusForbidden, "forbidden", "not allowed")
		return
	}
	if err := d.Store.DeleteMedia(r.Context(), m.ID); err != nil {
		d.serverError(w, "media: delete", err)
		return
	}
	thumb := ""
	if m.ThumbPath != nil {
		thumb = *m.ThumbPath
	}
	d.Media.Remove(m.FilePath, thumb)
	w.WriteHeader(http.StatusNoContent)
}
