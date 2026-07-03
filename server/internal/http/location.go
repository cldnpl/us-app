package httpapi

import (
	"errors"
	"net/http"
	"time"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/store"
)

type updateLocationRequest struct {
	Lat            float64  `json:"lat"`
	Lng            float64  `json:"lng"`
	Accuracy       *float64 `json:"accuracy"`
	Mode           string   `json:"mode"`           // live | onmyway | pin | off
	ExpiresMinutes *int     `json:"expiresMinutes"` // optional auto-stop
}

func (d Deps) handleUpdateLocation(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	var req updateLocationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	// "off" purges the stored coordinates (privacy: nothing kept when not sharing).
	if req.Mode == "off" {
		if err := d.Store.DeleteLocation(r.Context(), userID); err != nil {
			d.serverError(w, "location: delete", err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}

	mode := req.Mode
	if mode == "" {
		mode = "live"
	}
	var expires *time.Time
	if req.ExpiresMinutes != nil && *req.ExpiresMinutes > 0 {
		t := time.Now().Add(time.Duration(*req.ExpiresMinutes) * time.Minute)
		expires = &t
	}
	if err := d.Store.UpsertLocation(r.Context(), userID, req.Lat, req.Lng, req.Accuracy, mode, expires); err != nil {
		d.serverError(w, "location: upsert", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (d Deps) handleGetPartnerLocation(w http.ResponseWriter, r *http.Request) {
	c, userID, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	partner, err := d.Store.GetPartner(r.Context(), c.ID, userID)
	if err != nil {
		writeJSON(w, http.StatusOK, domain.PartnerLocation{Sharing: false})
		return
	}
	loc, err := d.Store.GetLocation(r.Context(), partner.ID)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusOK, domain.PartnerLocation{Sharing: false})
		return
	} else if err != nil {
		d.serverError(w, "location: get", err)
		return
	}
	name := partner.DisplayName
	writeJSON(w, http.StatusOK, domain.PartnerLocation{
		Sharing:     true,
		Lat:         &loc.Lat,
		Lng:         &loc.Lng,
		Mode:        &loc.SharingMode,
		PartnerName: &name,
		UpdatedAt:   &loc.UpdatedAt,
	})
}

func (d Deps) handleStopLocation(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if err := d.Store.DeleteLocation(r.Context(), userID); err != nil {
		d.serverError(w, "location: stop", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
