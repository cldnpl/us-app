package httpapi

import (
	"errors"
	"net/http"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/store"
)

type updateCycleRequest struct {
	Phase        string  `json:"phase"`
	CycleDay     *int    `json:"cycleDay"`
	PeriodInDays *int    `json:"periodInDays"`
	Note         *string `json:"note"`
}

// Coarse phases only — never raw symptoms. Kept in sync with the iOS CyclePhase.
var validCyclePhases = map[string]bool{
	"menstrual":  true,
	"follicular": true,
	"ovulation":  true,
	"luteal":     true,
	"pms":        true,
}

// handleUpdateCycle stores the caller's opt-in cycle summary for their partner
// to read. The client decides how much to include (phase only, or phase + days).
func (d Deps) handleUpdateCycle(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	var req updateCycleRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if !validCyclePhases[req.Phase] {
		writeError(w, http.StatusBadRequest, "invalid_phase", "unknown cycle phase")
		return
	}
	if err := d.Store.UpsertCycleShare(r.Context(), userID, req.Phase, req.CycleDay, req.PeriodInDays, req.Note); err != nil {
		d.serverError(w, "cycle: upsert", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// handleGetPartnerCycle returns the partner's shared summary, or {sharing:false}
// when they aren't paired or aren't sharing.
func (d Deps) handleGetPartnerCycle(w http.ResponseWriter, r *http.Request) {
	c, userID, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	partner, err := d.Store.GetPartner(r.Context(), c.ID, userID)
	if err != nil {
		writeJSON(w, http.StatusOK, domain.PartnerCycle{Sharing: false})
		return
	}
	share, err := d.Store.GetCycleShare(r.Context(), partner.ID)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusOK, domain.PartnerCycle{Sharing: false})
		return
	} else if err != nil {
		d.serverError(w, "cycle: get", err)
		return
	}
	name := partner.DisplayName
	writeJSON(w, http.StatusOK, domain.PartnerCycle{
		Sharing:      true,
		Phase:        &share.Phase,
		CycleDay:     share.CycleDay,
		PeriodInDays: share.PeriodInDays,
		Note:         share.Note,
		PartnerName:  &name,
		UpdatedAt:    &share.UpdatedAt,
	})
}

// handleStopCycle purges the caller's shared summary (turns sharing off).
func (d Deps) handleStopCycle(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if err := d.Store.DeleteCycleShare(r.Context(), userID); err != nil {
		d.serverError(w, "cycle: stop", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
