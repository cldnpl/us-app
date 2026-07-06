package httpapi

import (
	"net/http"
	"strings"
	"time"

	"github.com/sharepact/us/internal/http/middleware"
)

func (d Deps) handleGetMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
		return
	}
	u, err := d.Store.GetUserByID(r.Context(), userID)
	if err != nil {
		d.serverError(w, "me: get", err)
		return
	}
	writeJSON(w, http.StatusOK, toDomainUser(u))
}

type patchMeRequest struct {
	DisplayName    *string `json:"displayName"`
	Birthday       *string `json:"birthday"`       // ISO date, YYYY-MM-DD
	PartnerPronoun *string `json:"partnerPronoun"` // she | he | they
}

var validPronouns = map[string]bool{"she": true, "he": true, "they": true}

func (d Deps) handlePatchMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
		return
	}
	var req patchMeRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	var name *string
	if req.DisplayName != nil {
		n := strings.TrimSpace(*req.DisplayName)
		if n == "" {
			writeError(w, http.StatusBadRequest, "missing_name", "display name cannot be empty")
			return
		}
		name = &n
	}

	var bday *time.Time
	if req.Birthday != nil && *req.Birthday != "" {
		t, err := time.Parse("2006-01-02", *req.Birthday)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_date", "birthday must be YYYY-MM-DD")
			return
		}
		bday = &t
	}

	var pronoun *string
	if req.PartnerPronoun != nil && *req.PartnerPronoun != "" {
		if !validPronouns[*req.PartnerPronoun] {
			writeError(w, http.StatusBadRequest, "invalid_pronoun", "partnerPronoun must be she, he, or they")
			return
		}
		pronoun = req.PartnerPronoun
	}

	u, err := d.Store.UpdateUserProfile(r.Context(), userID, name, bday, pronoun)
	if err != nil {
		d.serverError(w, "me: update", err)
		return
	}
	writeJSON(w, http.StatusOK, toDomainUser(u))
}
