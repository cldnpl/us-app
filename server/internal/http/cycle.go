package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/push"
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

// How a phase is named in the notification to the partner. Deliberately gentle
// and vague enough to sit on a lock screen.
var cyclePhaseNames = map[string]string{
	"menstrual":  "her period",
	"follicular": "her follicular phase",
	"ovulation":  "her fertile window",
	"luteal":     "her luteal phase",
	"pms":        "the days before her period",
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
	// Read what the partner is currently seeing *before* overwriting it: the
	// app re-publishes this same summary every time a screen appears, so only a
	// real change is worth a notification.
	previous, prevErr := d.Store.GetCycleShare(r.Context(), userID)
	hadPrevious := prevErr == nil

	if err := d.Store.UpsertCycleShare(r.Context(), userID, req.Phase, req.CycleDay, req.PeriodInDays, req.Note); err != nil {
		d.serverError(w, "cycle: upsert", err)
		return
	}
	d.notifyCycleChange(r.Context(), userID, previous, hadPrevious, req)
	w.WriteHeader(http.StatusNoContent)
}

// notifyCycleChange tells the partner what actually changed in the summary just
// published: a new phase, or a new thought for the day. Nothing is sent the
// first time sharing is switched on — that isn't a change, and the partner will
// see the card as soon as they open the app.
func (d Deps) notifyCycleChange(ctx context.Context, userID string, previous store.CycleShare, hadPrevious bool, req updateCycleRequest) {
	if !hadPrevious {
		return
	}
	c, err := d.Store.GetCoupleForUser(ctx, userID)
	if err != nil {
		return
	}

	if previous.Phase != req.Phase {
		phase := cyclePhaseNames[req.Phase]
		if phase == "" {
			phase = "a new phase"
		}
		d.sendPartnerPush(ctx, c.ID, userID, func(name string) push.Notification {
			return push.Notification{
				Title: "Cycle & health",
				Body:  name + " has entered " + phase,
				Data:  map[string]string{"type": "cycle", "state": "phase"},
			}
		})
		return // one nudge per update: the phase is the bigger news
	}

	note := strings.TrimSpace(deref(req.Note))
	if note != "" && note != strings.TrimSpace(deref(previous.Note)) {
		d.sendPartnerPush(ctx, c.ID, userID, func(name string) push.Notification {
			return push.Notification{
				Title: "Cycle & health",
				Body:  name + " shared how she's feeling today",
				Data:  map[string]string{"type": "cycle", "state": "note"},
			}
		})
	}
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
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
