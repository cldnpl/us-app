package httpapi

import (
	"errors"
	"net/http"
	"time"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/store"
)

type updatePregnancyRequest struct {
	DueDate string `json:"dueDate"` // ISO date, YYYY-MM-DD
}

// handleUpdatePregnancy stores the caller's shared due date for their partner.
func (d Deps) handleUpdatePregnancy(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	var req updatePregnancyRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	due, perr := time.Parse("2006-01-02", req.DueDate)
	if perr != nil {
		writeError(w, http.StatusBadRequest, "invalid_date", "dueDate must be YYYY-MM-DD")
		return
	}
	if err := d.Store.UpsertPregnancyShare(r.Context(), userID, due); err != nil {
		d.serverError(w, "pregnancy: upsert", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// handleGetPartnerPregnancy returns the partner's shared due date, or
// {sharing:false} when they aren't paired or aren't sharing.
func (d Deps) handleGetPartnerPregnancy(w http.ResponseWriter, r *http.Request) {
	c, userID, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	partner, err := d.Store.GetPartner(r.Context(), c.ID, userID)
	if err != nil {
		writeJSON(w, http.StatusOK, domain.PartnerPregnancy{Sharing: false})
		return
	}
	share, err := d.Store.GetPregnancyShare(r.Context(), partner.ID)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusOK, domain.PartnerPregnancy{Sharing: false})
		return
	} else if err != nil {
		d.serverError(w, "pregnancy: get", err)
		return
	}
	name := partner.DisplayName
	writeJSON(w, http.StatusOK, domain.PartnerPregnancy{
		Sharing:     true,
		DueDate:     &share.DueDate,
		PartnerName: &name,
		UpdatedAt:   &share.UpdatedAt,
	})
}

// handleStopPregnancy purges the caller's shared due date (stop sharing).
func (d Deps) handleStopPregnancy(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if err := d.Store.DeletePregnancyShare(r.Context(), userID); err != nil {
		d.serverError(w, "pregnancy: stop", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
