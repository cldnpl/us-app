package httpapi

import (
	"errors"
	"net/http"

	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

func (d Deps) handleSendMissYou(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if !d.MissYouLimiter.Allow(userID) {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "you just sent one 💕 give it a moment")
		return
	}

	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return
	} else if err != nil {
		d.serverError(w, "missyou: couple", err)
		return
	}

	ev, err := d.Store.CreateMissYou(r.Context(), c.ID, userID, "miss_you")
	if err != nil {
		d.serverError(w, "missyou: create", err)
		return
	}

	// Notify the partner.
	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{Title: "💜", Body: name + " misses you", Data: map[string]string{"type": "miss_you"}}
	})

	writeJSON(w, http.StatusCreated, toDomainMissYou(ev))
}

func (d Deps) handleListMissYou(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return
	} else if err != nil {
		d.serverError(w, "missyou: couple", err)
		return
	}
	events, err := d.Store.ListMissYou(r.Context(), c.ID, 50)
	if err != nil {
		d.serverError(w, "missyou: list", err)
		return
	}
	out := make([]any, len(events))
	for i, e := range events {
		out[i] = toDomainMissYou(e)
	}
	writeJSON(w, http.StatusOK, map[string]any{"events": out})
}
