package httpapi

import (
	"net/http"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/http/middleware"
	"github.com/sharepact/us/internal/store"
)

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
