package httpapi

import (
	"context"
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

	// Notify the partner (fire-and-forget).
	sender, _ := d.Store.GetUserByID(r.Context(), userID)
	if partner, perr := d.Store.GetPartner(r.Context(), c.ID, userID); perr == nil {
		if tokens, terr := d.Store.GetDeviceTokens(r.Context(), partner.ID); terr == nil && len(tokens) > 0 {
			list := make([]string, len(tokens))
			for i, t := range tokens {
				list[i] = t.Token
			}
			name := sender.DisplayName
			if name == "" {
				name = "Your partner"
			}
			go func() {
				if err := d.Push.Send(context.Background(), list, push.Notification{
					Title: "💜",
					Body:  name + " misses you",
					Data:  map[string]string{"type": "miss_you"},
				}); err != nil {
					d.Logger.Warn("miss-you push failed", "err", err, "recipients", len(list))
				} else {
					d.Logger.Info("miss-you push sent", "recipients", len(list))
				}
			}()
		}
	}

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
