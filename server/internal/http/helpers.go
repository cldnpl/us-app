package httpapi

import (
	"context"
	"errors"
	"net/http"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/http/middleware"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// coupleForRequest returns the authenticated user's couple, writing the
// appropriate error (401 unauthenticated, 409 not paired) and returning ok=false.
func (d Deps) coupleForRequest(w http.ResponseWriter, r *http.Request) (store.Couple, string, bool) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return store.Couple{}, "", false
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return store.Couple{}, "", false
	}
	if err != nil {
		d.serverError(w, "couple lookup", err)
		return store.Couple{}, "", false
	}
	return c, userID, true
}

// sendPartnerPush delivers a notification to the other member of the couple.
// `build` receives the sender's display name so callers can compose the body.
func (d Deps) sendPartnerPush(ctx context.Context, coupleID, senderID string, build func(senderName string) push.Notification) {
	sender, _ := d.Store.GetUserByID(ctx, senderID)
	partner, err := d.Store.GetPartner(ctx, coupleID, senderID)
	if err != nil {
		return
	}
	tokens, err := d.Store.GetDeviceTokens(ctx, partner.ID)
	if err != nil || len(tokens) == 0 {
		return
	}
	list := make([]string, len(tokens))
	for i, t := range tokens {
		list[i] = t.Token
	}
	name := sender.DisplayName
	if name == "" {
		name = "Your partner"
	}
	notification := build(name)
	go func() {
		if err := d.Push.Send(context.Background(), list, notification); err != nil {
			d.Logger.Warn("partner push failed", "err", err, "recipients", len(list))
		} else {
			d.Logger.Info("partner push sent", "recipients", len(list))
		}
	}()
}

// authedUser returns the authenticated user id, writing a 401 if absent. Routes
// behind the Authenticator middleware will always have it set.
func (d Deps) authedUser(w http.ResponseWriter, r *http.Request) (string, bool) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
	}
	return userID, ok
}

func toDomainCouple(c store.Couple) domain.Couple {
	return domain.Couple{ID: c.ID, StartDate: c.StartDate, Status: c.Status, CreatedAt: c.CreatedAt}
}

func toDomainMissYou(m store.MissYou) domain.MissYouEvent {
	return domain.MissYouEvent{ID: m.ID, SenderID: m.SenderID, Kind: m.Kind, CreatedAt: m.CreatedAt}
}
