package httpapi

import (
	"context"
	"errors"
	"net/http"
	"sync"
	"time"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/push"
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
	d.notifyPartnerLocationChanged(r.Context(), userID)
	w.WriteHeader(http.StatusNoContent)
}

// locationPushThrottle remembers when each user last woke their partner, so a
// device streaming fixes every 100 m doesn't send a push per fix.
var (
	locationPushMu   sync.Mutex
	locationPushLast = map[string]time.Time{}
)

const locationPushInterval = 5 * time.Minute

// notifyPartnerLocationChanged sends a silent push so the partner's app can
// recompute the distance and reload its widgets without being opened. Silent,
// best-effort, and throttled — the widget also refreshes on its own schedule.
func (d Deps) notifyPartnerLocationChanged(ctx context.Context, userID string) {
	locationPushMu.Lock()
	last, ok := locationPushLast[userID]
	if ok && time.Since(last) < locationPushInterval {
		locationPushMu.Unlock()
		return
	}
	locationPushLast[userID] = time.Now()
	locationPushMu.Unlock()

	c, err := d.Store.GetCoupleForUser(ctx, userID)
	if err != nil {
		return // not paired: nobody to tell
	}
	d.sendPartnerPush(ctx, c.ID, userID, func(string) push.Notification {
		return push.Notification{Silent: true, Data: map[string]string{"type": "location_updated"}}
	})
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
