package httpapi

import (
	"errors"
	"net/http"
	"time"

	"github.com/sharepact/us/internal/store"
)

func (d Deps) handleGetCouple(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusOK, map[string]any{"paired": false})
		return
	} else if err != nil {
		d.serverError(w, "couple: get", err)
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	writeJSON(w, http.StatusOK, map[string]any{
		"paired":  true,
		"couple":  toDomainCouple(c),
		"partner": toDomainUser(partner),
	})
}

func (d Deps) handleDeleteCouple(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		w.WriteHeader(http.StatusNoContent)
		return
	} else if err != nil {
		d.serverError(w, "couple: get", err)
		return
	}
	if err := d.Store.DeleteCouple(r.Context(), c.ID); err != nil {
		d.serverError(w, "couple: delete", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type patchCoupleRequest struct {
	StartDate *string `json:"startDate"` // ISO date, YYYY-MM-DD
}

func (d Deps) handlePatchCouple(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return
	} else if err != nil {
		d.serverError(w, "couple: get", err)
		return
	}

	var req patchCoupleRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	var start *time.Time
	if req.StartDate != nil && *req.StartDate != "" {
		t, perr := time.Parse("2006-01-02", *req.StartDate)
		if perr != nil {
			writeError(w, http.StatusBadRequest, "invalid_date", "startDate must be YYYY-MM-DD")
			return
		}
		start = &t
	}
	updated, err := d.Store.UpdateCoupleStartDate(r.Context(), c.ID, start)
	if err != nil {
		d.serverError(w, "couple: update", err)
		return
	}
	writeJSON(w, http.StatusOK, toDomainCouple(updated))
}
