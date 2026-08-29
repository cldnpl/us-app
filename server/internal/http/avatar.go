package httpapi

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/sharepact/us/internal/http/middleware"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// Avatars live under `avatars/{yyyy}/{mm}/{uuid}.jpg` on disk. The path is
// bookkept in `users.avatar_path`; the URL served to the app is
// `/v1/users/{userId}/avatar`, resolved by handleServeAvatar.

// POST /v1/me/avatar (multipart: file)
func (d Deps) handleUploadAvatar(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(maxUploadBytes + (1 << 20)); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_upload", "could not read the photo")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing_file", "a photo is required")
		return
	}
	defer file.Close()

	id := uuid.NewString()
	// Reuse the couple photo pipeline (auto-orient + resize + JPEG). "avatars"
	// stands in for the coupleID bucket so the file lands under an obvious dir.
	fullRel, thumbRel, _, err := d.Media.SaveImage("avatars", id, file)
	if err != nil {
		d.Logger.Error("avatar: save image failed", "err", err)
		writeError(w, http.StatusBadRequest, "bad_image", "could not process that photo")
		return
	}
	// Best-effort cleanup of the previous avatar so the disk doesn't leak.
	if prev, gerr := d.Store.GetUserByID(r.Context(), userID); gerr == nil && prev.AvatarPath != nil {
		d.Media.Remove(*prev.AvatarPath, "")
	}
	// The full-size file is what we serve; the thumb is discarded — avatars are
	// small on screen but the SaveImage pipeline generates both.
	d.Media.Remove(thumbRel)

	u, err := d.Store.UpdateUserAvatar(r.Context(), userID, &fullRel)
	if err != nil {
		d.Media.Remove(fullRel)
		d.serverError(w, "avatar: update user", err)
		return
	}
	// A partner who's looking at your name should see the new photo without
	// waiting for their app to reload. Same nudge used for a name change.
	d.notifyPartnerProfileChanged(r.Context(), userID)
	// Also poke the partner's device with a lightweight push so an app that's
	// backgrounded refreshes when it foregrounds.
	if c, cerr := d.Store.GetCoupleForUser(r.Context(), userID); cerr == nil {
		d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
			return push.Notification{Data: map[string]string{"type": "profile"}}
		})
	}
	writeJSON(w, http.StatusOK, toDomainUser(u))
}

// DELETE /v1/me/avatar
func (d Deps) handleDeleteAvatar(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
		return
	}
	if prev, gerr := d.Store.GetUserByID(r.Context(), userID); gerr == nil && prev.AvatarPath != nil {
		d.Media.Remove(*prev.AvatarPath, "")
	}
	u, err := d.Store.UpdateUserAvatar(r.Context(), userID, nil)
	if err != nil {
		d.serverError(w, "avatar: clear", err)
		return
	}
	d.notifyPartnerProfileChanged(r.Context(), userID)
	writeJSON(w, http.StatusOK, toDomainUser(u))
}

// GET /v1/users/{userId}/avatar — streams the raw JPEG. Only the user themselves
// or their paired partner can fetch it.
func (d Deps) handleServeAvatar(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
		return
	}
	targetID := chi.URLParam(r, "userId")
	if targetID != userID {
		c, err := d.Store.GetCoupleForUser(r.Context(), userID)
		if errors.Is(err, store.ErrNotFound) || err != nil {
			writeError(w, http.StatusForbidden, "forbidden", "not allowed")
			return
		}
		partner, perr := d.Store.GetPartner(r.Context(), c.ID, userID)
		if perr != nil || partner.ID != targetID {
			writeError(w, http.StatusForbidden, "forbidden", "not allowed")
			return
		}
	}
	u, err := d.Store.GetUserByID(r.Context(), targetID)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "not found")
		return
	}
	if u.AvatarPath == nil || *u.AvatarPath == "" {
		writeError(w, http.StatusNotFound, "no_avatar", "no avatar set")
		return
	}
	w.Header().Set("Cache-Control", "private, max-age=3600")
	http.ServeFile(w, r, d.Media.Abs(*u.AvatarPath))
}
