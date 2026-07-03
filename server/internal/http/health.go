package httpapi

import (
	"context"
	"net/http"
	"time"
)

// handleHealth reports liveness plus a database round-trip check.
func (d Deps) handleHealth(w http.ResponseWriter, r *http.Request) {
	resp := map[string]any{
		"status":  "ok",
		"service": "us-api",
		"env":     d.Config.Env,
	}

	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := d.Pool.Ping(ctx); err != nil {
		resp["status"] = "degraded"
		resp["db"] = "unreachable"
		writeJSON(w, http.StatusServiceUnavailable, resp)
		return
	}
	resp["db"] = "ok"
	writeJSON(w, http.StatusOK, resp)
}
