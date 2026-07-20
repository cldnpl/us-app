package httpapi

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/sharepact/us/internal/http/middleware"
	"github.com/sharepact/us/internal/mail"
	"github.com/sharepact/us/internal/store"
)

// emailCodeTTL is how long a change code stays valid.
const emailCodeTTL = 15 * time.Minute

type requestEmailChangeRequest struct {
	NewEmail string `json:"newEmail"`
}

// requestEmailChangeResponse tells the app where the code went and how long it
// has. DevCode is only ever populated in a dev environment with no real mailer
// configured — see handleRequestEmailChange.
type requestEmailChangeResponse struct {
	SentTo    string    `json:"sentTo"`
	ExpiresAt time.Time `json:"expiresAt"`
	DevCode   string    `json:"devCode,omitempty"`
}

// handleRequestEmailChange starts an email change: it mints a 6-digit code and
// sends it to the *new* address, which is what proves the user can receive mail
// there. Nothing on the account changes until the code is confirmed.
func (d Deps) handleRequestEmailChange(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
		return
	}
	var req requestEmailChangeRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	newEmail := strings.ToLower(strings.TrimSpace(req.NewEmail))
	if !emailRegex.MatchString(newEmail) {
		writeError(w, http.StatusBadRequest, "invalid_email", "that doesn't look like an email address")
		return
	}

	current, err := d.Store.GetUserByID(r.Context(), userID)
	if err != nil {
		d.serverError(w, "email change: get user", err)
		return
	}
	if current.Email != nil && strings.EqualFold(*current.Email, newEmail) {
		writeError(w, http.StatusBadRequest, "same_email", "that's already your email address")
		return
	}

	taken, err := d.Store.EmailInUse(r.Context(), newEmail, userID)
	if err != nil {
		d.serverError(w, "email change: in use", err)
		return
	}
	if taken {
		writeError(w, http.StatusConflict, "email_taken", "that email is already in use")
		return
	}

	// Charge the throttle only now that we know we're really going to send.
	// Checking earlier would let a typo'd address burn the user's budget and
	// lock them out of their own correction.
	if !d.EmailCodeLimiter.Allow(userID) {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "wait a minute before asking for another code")
		return
	}

	code, err := generateNumericCode(6)
	if err != nil {
		d.serverError(w, "email change: code", err)
		return
	}
	expiresAt := time.Now().Add(emailCodeTTL)
	if err := d.Store.CreateEmailChangeCode(r.Context(), userID, newEmail, hashEmailCode(code), expiresAt); err != nil {
		d.serverError(w, "email change: create", err)
		return
	}

	if err := d.Mail.Send(r.Context(), mail.Message{
		To:      newEmail,
		Subject: "Your Us. verification code",
		Body: fmt.Sprintf(
			"Hi %s,\n\nYour code to confirm this email address for Us. is:\n\n    %s\n\n"+
				"It expires in %d minutes. If you didn't ask to change your email, you can ignore this.\n\n— Us.\n",
			current.DisplayName, code, int(emailCodeTTL.Minutes())),
	}); err != nil {
		d.Logger.Error("email change: send", "err", err)
		writeError(w, http.StatusBadGateway, "mail_failed", "couldn't send the code, try again")
		return
	}

	resp := requestEmailChangeResponse{SentTo: newEmail, ExpiresAt: expiresAt}
	// With no mail provider configured there is no inbox to read the code from,
	// which would make the flow impossible to exercise. In dev only, hand it
	// back so the app can show it. Never in any other environment.
	if !d.Mail.Deliverable() && d.Config.Env == "dev" {
		resp.DevCode = code
	}
	writeJSON(w, http.StatusAccepted, resp)
}

type confirmEmailChangeRequest struct {
	Code string `json:"code"`
}

// handleConfirmEmailChange spends the code and moves the address onto the
// account. Wrong/expired codes all return the same error so a guesser learns
// nothing about which live code exists.
func (d Deps) handleConfirmEmailChange(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "unauthorized")
		return
	}
	var req confirmEmailChangeRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	code := strings.TrimSpace(req.Code)
	if code == "" {
		writeError(w, http.StatusBadRequest, "missing_code", "enter the code we sent you")
		return
	}

	u, err := d.Store.RedeemEmailChange(r.Context(), userID, hashEmailCode(code))
	switch {
	case errors.Is(err, store.ErrEmailCodeInvalid):
		writeError(w, http.StatusBadRequest, "invalid_code", "that code is wrong or has expired")
		return
	case errors.Is(err, store.ErrEmailTaken):
		writeError(w, http.StatusConflict, "email_taken", "that email is already in use")
		return
	case err != nil:
		d.serverError(w, "email change: redeem", err)
		return
	}

	// The partner shows this person's details in their app, so nudge their
	// device to refetch rather than waiting for its next natural refresh.
	d.notifyPartnerProfileChanged(r.Context(), userID)

	writeJSON(w, http.StatusOK, toDomainUser(u))
}

// hashEmailCode is the storage form of a code — the raw code is never persisted.
func hashEmailCode(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}

// generateNumericCode returns a cryptographically random decimal string,
// zero-padded to n digits so every code is the same length.
func generateNumericCode(n int) (string, error) {
	max := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(n)), nil)
	v, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%0*d", n, v), nil
}
