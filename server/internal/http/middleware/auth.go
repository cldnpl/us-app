package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/sharepact/us/internal/auth"
)

type ctxKey string

const userIDKey ctxKey = "userID"

// Authenticator returns middleware that requires a valid Bearer access token and
// stores the authenticated user id in the request context.
func Authenticator(secret []byte) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if !strings.HasPrefix(header, "Bearer ") {
				unauthorized(w)
				return
			}
			userID, err := auth.VerifyAccessToken(secret, strings.TrimPrefix(header, "Bearer "))
			if err != nil {
				unauthorized(w)
				return
			}
			ctx := context.WithValue(r.Context(), userIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// UserID extracts the authenticated user id set by Authenticator.
func UserID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey).(string)
	return id, ok
}

func unauthorized(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_, _ = w.Write([]byte(`{"error":"unauthorized","code":"unauthorized"}`))
}
