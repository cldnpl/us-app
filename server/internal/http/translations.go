package httpapi

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/i18n"
)

type translationsResponse struct {
	Lang    string            `json:"lang"`
	Strings map[string]string `json:"strings"`
}

// langParam reads the optional ?lang= query param shared by every catalog
// display endpoint (quiz/hwdykm/debate). Empty/unknown values fall through to
// English via quizCategoriesFor/hwdykmPacksFor/debatePacksFor, same as an
// unrecognized code falls back in handleGetTranslations.
func langParam(r *http.Request) string {
	return r.URL.Query().Get("lang")
}

// GET /v1/translations/{lang} — UI string table for one language. Public: the
// app needs this before login (onboarding, sign-in screen strings), and it's
// static per deploy, so it's safe and cheap to leave unauthenticated behind
// just an IP rate limit. Unknown languages fall back to English rather than
// 404ing — the client already has its own English fallback baked in, so this
// just saves it a round trip when a language code is unrecognized.
func (d Deps) handleGetTranslations(w http.ResponseWriter, r *http.Request) {
	lang := chi.URLParam(r, "lang")
	strings, ok := i18n.Strings(lang)
	if !ok {
		lang = "en"
		strings, _ = i18n.Strings("en")
	}
	// Content only changes on deploy, so client/CDN caching is free money.
	w.Header().Set("Cache-Control", "public, max-age=3600")
	writeJSON(w, http.StatusOK, translationsResponse{Lang: lang, Strings: strings})
}
