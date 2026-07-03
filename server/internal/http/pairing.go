package httpapi

import (
	"context"
	"crypto/rand"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/sharepact/us/internal/store"
)

// codeAlphabet excludes visually ambiguous characters (I, O, 0, 1).
const codeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func randomCode(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	out := make([]byte, n)
	for i := range b {
		out[i] = codeAlphabet[int(b[i])%len(codeAlphabet)]
	}
	return string(out), nil
}

func (d Deps) generateUniqueCode(ctx context.Context) (string, error) {
	for i := 0; i < 10; i++ {
		code, err := randomCode(6)
		if err != nil {
			return "", err
		}
		exists, err := d.Store.PairingCodeExists(ctx, code)
		if err != nil {
			return "", err
		}
		if !exists {
			return code, nil
		}
	}
	return "", errors.New("could not allocate a unique pairing code")
}

func (d Deps) handleCreatePairingCode(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if _, err := d.Store.GetCoupleForUser(r.Context(), userID); err == nil {
		writeError(w, http.StatusConflict, "already_paired", "you are already paired with a partner")
		return
	} else if !errors.Is(err, store.ErrNotFound) {
		d.serverError(w, "pairing: couple check", err)
		return
	}

	// Reuse the user's existing active code so it stays stable across visits.
	if code, expiresAt, err := d.Store.GetActivePairingCode(r.Context(), userID); err == nil {
		writeJSON(w, http.StatusOK, map[string]any{"code": code, "expiresAt": expiresAt})
		return
	} else if !errors.Is(err, store.ErrNotFound) {
		d.serverError(w, "pairing: active code", err)
		return
	}

	code, err := d.generateUniqueCode(r.Context())
	if err != nil {
		d.serverError(w, "pairing: generate", err)
		return
	}
	expiresAt := time.Now().Add(24 * time.Hour)
	if err := d.Store.CreatePairingCode(r.Context(), userID, code, expiresAt); err != nil {
		d.serverError(w, "pairing: create", err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"code": code, "expiresAt": expiresAt})
}

type redeemRequest struct {
	Code string `json:"code"`
}

func (d Deps) handleRedeemPairing(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	var req redeemRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	code := strings.ToUpper(strings.TrimSpace(req.Code))
	if code == "" {
		writeError(w, http.StatusBadRequest, "missing_code", "a pairing code is required")
		return
	}

	c, err := d.Store.RedeemPairing(r.Context(), code, userID)
	switch {
	case errors.Is(err, store.ErrPairingInvalid):
		writeError(w, http.StatusBadRequest, "invalid_code", "that code is invalid or has expired")
		return
	case errors.Is(err, store.ErrSelfPair):
		writeError(w, http.StatusBadRequest, "self_pair", "you cannot pair with yourself")
		return
	case errors.Is(err, store.ErrAlreadyPaired):
		writeError(w, http.StatusConflict, "already_paired", "one of you is already paired")
		return
	case err != nil:
		d.serverError(w, "pairing: redeem", err)
		return
	}

	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	writeJSON(w, http.StatusCreated, map[string]any{
		"paired":  true,
		"couple":  toDomainCouple(c),
		"partner": toDomainUser(partner),
	})
}
