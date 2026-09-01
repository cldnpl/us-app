package httpapi

import (
	"log/slog"
	"time"

	"github.com/sharepact/us/internal/store"
)

// Per-language deep copies of the three static catalogs, built once at boot
// by LoadCatalogTranslations. Reads only after boot (the HTTP server isn't
// listening yet while these are built), so no locking is needed — same
// pattern as the catalogs themselves, which are plain package vars.
var (
	localizedQuizCatalog = map[string][]catalogCategory{}
	localizedHwdykmPacks = map[string][]hwdykmPack{}
	localizedDebatePacks = map[string][]debatePack{}
)

// LoadCatalogTranslations builds the per-language catalog copies from the
// full content_translations table, called once at server boot (see
// cmd/api/main.go) after the store is ready. Logs a warning if it takes
// longer than a second — the catalogs are small enough today that it should
// be near-instant; a regression here would mean this no longer scales the
// way it was designed to.
func LoadCatalogTranslations(logger *slog.Logger, rows []store.ContentTranslation) {
	start := time.Now()

	byKey := make(map[string]string, len(rows)) // "lang|contentType|contentID|field" -> value
	langs := map[string]bool{}
	for _, r := range rows {
		byKey[translationKey(r.Lang, r.ContentType, r.ContentID, r.Field)] = r.Value
		langs[r.Lang] = true
	}

	lookup := func(lang, contentType, contentID, field string) (string, bool) {
		v, ok := byKey[translationKey(lang, contentType, contentID, field)]
		return v, ok
	}

	for lang := range langs {
		localizedQuizCatalog[lang] = buildLocalizedQuizCatalog(lang, lookup)
		localizedHwdykmPacks[lang] = buildLocalizedHwdykmPacks(lang, lookup)
		localizedDebatePacks[lang] = buildLocalizedDebatePacks(lang, lookup)
	}

	elapsed := time.Since(start)
	logger.Info("catalog translations loaded", "languages", len(langs), "rows", len(rows), "took", elapsed)
	if elapsed > time.Second {
		logger.Warn("catalog translation precompute took over 1s — revisit at this scale", "took", elapsed)
	}
}

type fieldLookup func(lang, contentType, contentID, field string) (string, bool)

func translationKey(lang, contentType, contentID, field string) string {
	return lang + "|" + contentType + "|" + contentID + "|" + field
}

func localize(lang, contentType, contentID, field, fallback string, lookup fieldLookup) string {
	if v, ok := lookup(lang, contentType, contentID, field); ok && v != "" {
		return v
	}
	return fallback
}

func buildLocalizedQuizCatalog(lang string, lookup fieldLookup) []catalogCategory {
	out := make([]catalogCategory, len(quizCatalog))
	for ci, cat := range quizCatalog {
		cat.Title = localize(lang, "quiz_category", cat.ID, "title", cat.Title, lookup)
		cat.Quizzes = make([]catalogQuiz, len(quizCatalog[ci].Quizzes))
		for qi, quiz := range quizCatalog[ci].Quizzes {
			quiz.Title = localize(lang, "quiz", quiz.ID, "title", quiz.Title, lookup)
			quiz.Questions = make([]catalogQuestion, len(quizCatalog[ci].Quizzes[qi].Questions))
			for qsi, q := range quizCatalog[ci].Quizzes[qi].Questions {
				q.Prompt = localize(lang, "quiz_question", q.ID, "prompt", q.Prompt, lookup)
				q.Options = make([]catalogOption, len(q.Options))
				for oi, o := range quizCatalog[ci].Quizzes[qi].Questions[qsi].Options {
					o.Label = localize(lang, "quiz_question", q.ID, "option:"+o.ID, o.Label, lookup)
					q.Options[oi] = o
				}
				quiz.Questions[qsi] = q
			}
			cat.Quizzes[qi] = quiz
		}
		out[ci] = cat
	}
	return out
}

func buildLocalizedHwdykmPacks(lang string, lookup fieldLookup) []hwdykmPack {
	out := make([]hwdykmPack, len(hwdykmPacks))
	for pi, pack := range hwdykmPacks {
		pack.Title = localize(lang, "hwdykm_pack", pack.ID, "title", pack.Title, lookup)
		pack.Questions = make([]hwdykmQuestion, len(hwdykmPacks[pi].Questions))
		for qi, q := range hwdykmPacks[pi].Questions {
			q.Prompt = localize(lang, "hwdykm_question", q.ID, "prompt", q.Prompt, lookup)
			q.Options = make([]hwdykmOption, len(q.Options))
			for oi, o := range hwdykmPacks[pi].Questions[qi].Options {
				o.Label = localize(lang, "hwdykm_question", q.ID, "option:"+o.ID, o.Label, lookup)
				q.Options[oi] = o
			}
			pack.Questions[qi] = q
		}
		out[pi] = pack
	}
	return out
}

func buildLocalizedDebatePacks(lang string, lookup fieldLookup) []debatePack {
	out := make([]debatePack, len(debatePacks))
	for pi, pack := range debatePacks {
		pack.Title = localize(lang, "debate_pack", pack.ID, "title", pack.Title, lookup)
		pack.Motions = make([]debateMotion, len(debatePacks[pi].Motions))
		for mi, m := range debatePacks[pi].Motions {
			m.Prompt = localize(lang, "debate_motion", m.ID, "prompt", m.Prompt, lookup)
			pack.Motions[mi] = m
		}
		out[pi] = pack
	}
	return out
}

// quizCategoriesFor returns the quiz catalog for lang, falling back to the
// English default when lang is "en", unknown, or unset.
func quizCategoriesFor(lang string) []catalogCategory {
	if cat, ok := localizedQuizCatalog[lang]; ok {
		return cat
	}
	return quizCatalog
}

func hwdykmPacksFor(lang string) []hwdykmPack {
	if p, ok := localizedHwdykmPacks[lang]; ok {
		return p
	}
	return hwdykmPacks
}

func debatePacksFor(lang string) []debatePack {
	if p, ok := localizedDebatePacks[lang]; ok {
		return p
	}
	return debatePacks
}

func findQuizIn(categories []catalogCategory, quizID string) (catalogQuiz, bool) {
	for _, cat := range categories {
		for _, q := range cat.Quizzes {
			if q.ID == quizID {
				return q, true
			}
		}
	}
	return catalogQuiz{}, false
}

// findQuizAndCategoryIn returns the quiz alongside its containing category —
// used by rotation to key generation state per category rather than per quiz.
func findQuizAndCategoryIn(categories []catalogCategory, quizID string) (catalogCategory, catalogQuiz, bool) {
	for _, cat := range categories {
		for _, q := range cat.Quizzes {
			if q.ID == quizID {
				return cat, q, true
			}
		}
	}
	return catalogCategory{}, catalogQuiz{}, false
}

func findHwdykmPackIn(packs []hwdykmPack, id string) (hwdykmPack, bool) {
	for _, p := range packs {
		if p.ID == id {
			return p, true
		}
	}
	return hwdykmPack{}, false
}

func findDebatePackIn(packs []debatePack, id string) (debatePack, bool) {
	for _, p := range packs {
		if p.ID == id {
			return p, true
		}
	}
	return debatePack{}, false
}
