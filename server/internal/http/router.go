package httpapi

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sharepact/us/internal/auth"
	"github.com/sharepact/us/internal/config"
	"github.com/sharepact/us/internal/http/middleware"
	"github.com/sharepact/us/internal/media"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// Deps carries the shared dependencies every handler needs.
type Deps struct {
	Config *config.Config
	Pool   *pgxpool.Pool
	Logger *slog.Logger
	Store  *store.Store
	Apple  *auth.AppleVerifier
	Push   push.Sender
	Media  *media.Storage

	MissYouLimiter *middleware.RateLimiter
}

// NewRouter builds the top-level HTTP handler with global middleware and routes.
func NewRouter(d Deps) http.Handler {
	// Per-user throttle for the Miss You button (~1 every 2s, burst 10).
	d.MissYouLimiter = middleware.NewRateLimiter(0.5, 10)

	r := chi.NewRouter()

	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(30 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   d.Config.AllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Authorization", "Content-Type"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.Get("/health", d.handleHealth)

	authLimiter := middleware.NewRateLimiter(5, 20) // per-IP throttle for auth endpoints
	requireAuth := middleware.Authenticator(d.Config.JWTSecret)

	r.Route("/v1", func(r chi.Router) {
		r.Get("/ping", func(w http.ResponseWriter, _ *http.Request) {
			writeJSON(w, http.StatusOK, map[string]string{"pong": "us"})
		})

		// Public auth endpoints (rate limited by IP).
		r.Group(func(r chi.Router) {
			r.Use(authLimiter.ByIP)
			r.Post("/auth/register", d.handleRegister)
			r.Post("/auth/login", d.handleLogin)
			r.Post("/auth/apple", d.handleApple)
			r.Post("/auth/refresh", d.handleRefresh)
			r.Post("/auth/logout", d.handleLogout)
		})

		// Protected endpoints (require a valid access token).
		r.Group(func(r chi.Router) {
			r.Use(requireAuth)

			r.Get("/me", d.handleGetMe)
			r.Patch("/me", d.handlePatchMe)

			r.Post("/pairing/code", d.handleCreatePairingCode)
			r.Post("/pairing/redeem", d.handleRedeemPairing)
			r.Get("/couple", d.handleGetCouple)
			r.Patch("/couple", d.handlePatchCouple)
			r.Delete("/couple", d.handleDeleteCouple)

			r.Post("/devices", d.handleRegisterDevice)
			r.Delete("/devices", d.handleDeleteDevice)

			r.Post("/miss-you", d.handleSendMissYou)
			r.Get("/miss-you", d.handleListMissYou)

			r.Post("/media", d.handleUploadMedia)
			r.Get("/media", d.handleListMedia)
			r.Get("/media/{id}/file", d.handleServeMedia(false))
			r.Get("/media/{id}/thumb", d.handleServeMedia(true))
			r.Delete("/media/{id}", d.handleDeleteMedia)

			r.Get("/milestones", d.handleListMilestones)
			r.Post("/milestones", d.handleCreateMilestone)
			r.Patch("/milestones/{id}", d.handleUpdateMilestone)
			r.Delete("/milestones/{id}", d.handleDeleteMilestone)

			r.Get("/journal", d.handleListJournal)
			r.Post("/journal", d.handleCreateJournalEntry)
			r.Post("/journal/{id}/photos", d.handleUploadJournalPhoto)
			r.Delete("/journal/{id}", d.handleDeleteJournalEntry)
			r.Get("/reunions", d.handleListReunions)
			r.Post("/reunions", d.handleCreateReunion)
			r.Delete("/reunions/{id}", d.handleDeleteReunion)

			r.Put("/location", d.handleUpdateLocation)
			r.Get("/location", d.handleGetPartnerLocation)
			r.Delete("/location", d.handleStopLocation)

			r.Put("/cycle", d.handleUpdateCycle)
			r.Get("/cycle", d.handleGetPartnerCycle)
			r.Delete("/cycle", d.handleStopCycle)

			r.Put("/pregnancy", d.handleUpdatePregnancy)
			r.Get("/pregnancy", d.handleGetPartnerPregnancy)
			r.Delete("/pregnancy", d.handleStopPregnancy)

			r.Get("/games/{type}", d.handleGetGame)
			r.Post("/games/{type}/move", d.handleGameMove)
			r.Post("/games/{type}/new", d.handleNewGame)

			r.Get("/question", d.handleGetQuestion)
			r.Post("/question", d.handleAnswerQuestion)

			r.Get("/quiz/daily", d.handleGetDailyQuiz)
			r.Post("/quiz/daily/answer", d.handleAnswerDailyQuiz)
			r.Get("/quiz/categories", d.handleListQuizCategories)
			r.Get("/quiz/categories/{id}", d.handleGetQuizCategory)
			r.Get("/quiz/{quizId}", d.handleGetQuiz)
			r.Post("/quiz/{quizId}/answer", d.handleAnswerQuiz)

			r.Get("/games/hwdykm/packs", d.handleListHwdykmPacks)
			r.Get("/games/hwdykm/packs/{id}", d.handleGetHwdykmPack)
			r.Post("/games/hwdykm/packs/{id}/answer", d.handleAnswerHwdykmPack)
		})
	})

	return r
}
