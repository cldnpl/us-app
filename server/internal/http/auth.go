package httpapi

import (
	"context"
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/sharepact/us/internal/auth"
	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/store"
)

var emailRegex = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

type authResponse struct {
	AccessToken  string      `json:"accessToken"`
	RefreshToken string      `json:"refreshToken"`
	User         domain.User `json:"user"`
}

func (d Deps) serverError(w http.ResponseWriter, context string, err error) {
	d.Logger.Error(context, "err", err)
	writeError(w, http.StatusInternalServerError, "server_error", "something went wrong")
}

func toDomainUser(u store.User) domain.User {
	return domain.User{
		ID:              u.ID,
		Email:           u.Email,
		EmailVerified:   u.EmailVerified,
		DisplayName:     u.DisplayName,
		AvatarPath:      u.AvatarPath,
		Birthday:        u.Birthday,
		PartnerPronoun:  u.PartnerPronoun,
		HasCycle:        u.HasCycle,
		CycleShareLevel: u.CycleShareLevel,
		CreatedAt:       u.CreatedAt,
	}
}

func (d Deps) issueTokens(ctx context.Context, u store.User) (authResponse, error) {
	access, err := auth.IssueAccessToken(d.Config.JWTSecret, u.ID, d.Config.AccessTokenTTL)
	if err != nil {
		return authResponse{}, err
	}
	raw, hash, err := auth.GenerateRefreshToken()
	if err != nil {
		return authResponse{}, err
	}
	if err := d.Store.CreateRefreshToken(ctx, u.ID, hash, time.Now().Add(d.Config.RefreshTokenTTL)); err != nil {
		return authResponse{}, err
	}
	return authResponse{AccessToken: access, RefreshToken: raw, User: toDomainUser(u)}, nil
}

// ---- email/password ----

type registerRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"displayName"`
}

func (d Deps) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if !emailRegex.MatchString(req.Email) {
		writeError(w, http.StatusBadRequest, "invalid_email", "a valid email is required")
		return
	}
	if len(req.Password) < 8 {
		writeError(w, http.StatusBadRequest, "weak_password", "password must be at least 8 characters")
		return
	}
	if req.DisplayName == "" {
		writeError(w, http.StatusBadRequest, "missing_name", "display name is required")
		return
	}

	if _, err := d.Store.GetUserByEmail(r.Context(), req.Email); err == nil {
		writeError(w, http.StatusConflict, "email_taken", "that email is already registered")
		return
	} else if !errors.Is(err, store.ErrNotFound) {
		d.serverError(w, "register: lookup", err)
		return
	}

	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		d.serverError(w, "register: hash", err)
		return
	}
	email := req.Email
	u, err := d.Store.CreateUser(r.Context(), store.CreateUserParams{
		Email:        &email,
		PasswordHash: &hash,
		DisplayName:  req.DisplayName,
	})
	if err != nil {
		d.serverError(w, "register: create", err)
		return
	}
	resp, err := d.issueTokens(r.Context(), u)
	if err != nil {
		d.serverError(w, "register: tokens", err)
		return
	}
	writeJSON(w, http.StatusCreated, resp)
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (d Deps) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	u, err := d.Store.GetUserByEmail(r.Context(), req.Email)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "incorrect email or password")
		return
	} else if err != nil {
		d.serverError(w, "login: lookup", err)
		return
	}
	if u.PasswordHash == nil {
		writeError(w, http.StatusUnauthorized, "no_password", "this account uses Sign in with Apple")
		return
	}
	ok, err := auth.VerifyPassword(req.Password, *u.PasswordHash)
	if err != nil || !ok {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "incorrect email or password")
		return
	}
	resp, err := d.issueTokens(r.Context(), u)
	if err != nil {
		d.serverError(w, "login: tokens", err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

// ---- Sign in with Apple ----

type appleRequest struct {
	IdentityToken string `json:"identityToken"`
	DisplayName   string `json:"displayName"`
}

func (d Deps) handleApple(w http.ResponseWriter, r *http.Request) {
	var req appleRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.IdentityToken == "" {
		writeError(w, http.StatusBadRequest, "missing_token", "identityToken is required")
		return
	}
	sub, email, err := d.Apple.Verify(r.Context(), req.IdentityToken)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "apple_invalid", "could not verify Apple identity token")
		return
	}

	u, err := d.Store.GetUserByAppleID(r.Context(), sub)
	if errors.Is(err, store.ErrNotFound) {
		name := strings.TrimSpace(req.DisplayName)
		if name == "" {
			name = "Partner"
		}
		u, err = d.Store.CreateUser(r.Context(), store.CreateUserParams{
			Email:       email,
			AppleUserID: &sub,
			DisplayName: name,
		})
		if err != nil {
			d.serverError(w, "apple: create", err)
			return
		}
	} else if err != nil {
		d.serverError(w, "apple: lookup", err)
		return
	}
	resp, err := d.issueTokens(r.Context(), u)
	if err != nil {
		d.serverError(w, "apple: tokens", err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

// ---- session lifecycle ----

type refreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

func (d Deps) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, "missing_token", "refreshToken is required")
		return
	}
	tokenID, userID, err := d.Store.GetActiveRefreshToken(r.Context(), auth.HashRefreshToken(req.RefreshToken))
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusUnauthorized, "invalid_refresh", "refresh token is invalid or expired")
		return
	} else if err != nil {
		d.serverError(w, "refresh: lookup", err)
		return
	}
	// Rotate: revoke the used token before minting a new pair.
	if err := d.Store.RevokeRefreshToken(r.Context(), tokenID); err != nil {
		d.serverError(w, "refresh: revoke", err)
		return
	}
	u, err := d.Store.GetUserByID(r.Context(), userID)
	if err != nil {
		d.serverError(w, "refresh: user", err)
		return
	}
	resp, err := d.issueTokens(r.Context(), u)
	if err != nil {
		d.serverError(w, "refresh: tokens", err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (d Deps) handleLogout(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.RefreshToken != "" {
		_ = d.Store.RevokeRefreshTokenByHash(r.Context(), auth.HashRefreshToken(req.RefreshToken))
	}
	w.WriteHeader(http.StatusNoContent)
}
