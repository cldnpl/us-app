package httpapi

import (
	"net/http"
	"strings"
)

type registerDeviceRequest struct {
	ApnsToken   string `json:"apnsToken"`
	Environment string `json:"environment"` // "sandbox" or "production"
}

func (d Deps) handleRegisterDevice(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	var req registerDeviceRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	tokenStr := strings.TrimSpace(req.ApnsToken)
	if tokenStr == "" {
		writeError(w, http.StatusBadRequest, "missing_token", "apnsToken is required")
		return
	}
	env := req.Environment
	if env != "production" {
		env = "sandbox"
	}
	if err := d.Store.UpsertDevice(r.Context(), userID, tokenStr, "ios", env); err != nil {
		d.serverError(w, "device: upsert", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type deleteDeviceRequest struct {
	ApnsToken string `json:"apnsToken"`
}

func (d Deps) handleDeleteDevice(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	var req deleteDeviceRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.ApnsToken) == "" {
		writeError(w, http.StatusBadRequest, "missing_token", "apnsToken is required")
		return
	}
	if err := d.Store.DeleteDevice(r.Context(), userID, req.ApnsToken); err != nil {
		d.serverError(w, "device: delete", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
