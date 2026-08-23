package httpapi

import (
	"log/slog"
	"testing"

	"github.com/sharepact/us/internal/store"
)

func TestLocalizedCatalogsSubstituteFieldsAndFallbackPerField(t *testing.T) {
	rows := []store.ContentTranslation{
		{ContentType: "quiz_category", ContentID: "starters", Field: "title", Lang: "es", Value: "Para empezar"},
		{ContentType: "quiz", ContentID: "starters_favorite_things", Field: "title", Lang: "es", Value: "Cosas favoritas"},
		{ContentType: "quiz_question", ContentID: "starters_favorite_things_q1", Field: "prompt", Lang: "es", Value: "¿Cuál prefieres?"},
		{ContentType: "quiz_question", ContentID: "starters_favorite_things_q1", Field: "option:opt0", Lang: "es", Value: "Playa"},
		{ContentType: "hwdykm_pack", ContentID: "favorites", Field: "title", Lang: "es", Value: "Favoritos"},
		{ContentType: "hwdykm_question", ContentID: "favorites_q1", Field: "option:opt0", Lang: "es", Value: "Pizza traducida"},
		{ContentType: "debate_pack", ContentID: "hot_takes", Field: "title", Lang: "es", Value: "Opiniones candentes"},
		{ContentType: "debate_motion", ContentID: "hot_takes_r1", Field: "prompt", Lang: "es", Value: "Una opinión traducida."},
	}
	byKey := make(map[string]string, len(rows))
	for _, row := range rows {
		byKey[translationKey(row.Lang, row.ContentType, row.ContentID, row.Field)] = row.Value
	}
	lookup := func(lang, contentType, contentID, field string) (string, bool) {
		value, ok := byKey[translationKey(lang, contentType, contentID, field)]
		return value, ok
	}

	quiz, found := findQuizIn(buildLocalizedQuizCatalog("es", lookup), "starters_favorite_things")
	if !found {
		t.Fatal("localized quiz not found")
	}
	if quiz.Title != "Cosas favoritas" || quiz.Questions[0].Prompt != "¿Cuál prefieres?" {
		t.Fatalf("localized quiz fields = %#v", quiz)
	}
	if quiz.Questions[0].Options[0].ID != "opt0" || quiz.Questions[0].Options[0].Label != "Playa" {
		t.Fatalf("localized option = %#v", quiz.Questions[0].Options[0])
	}
	// No translation row was supplied for the second option, so it remains
	// English while the first option is translated.
	if quiz.Questions[0].Options[1].Label != "Mountains" {
		t.Fatalf("missing option translation did not fall back: %q", quiz.Questions[0].Options[1].Label)
	}

	packs := buildLocalizedHwdykmPacks("es", lookup)
	if packs[0].Title != "Favoritos" || packs[0].Questions[0].Options[0].Label != "Pizza traducida" {
		t.Fatalf("localized HWDYKM pack = %#v", packs[0])
	}
	debates := buildLocalizedDebatePacks("es", lookup)
	if debates[0].Title != "Opiniones candentes" || debates[0].Motions[0].Prompt != "Una opinión traducida." {
		t.Fatalf("localized debate pack = %#v", debates[0])
	}

	// Exercise the boot loader too, including its per-language map population.
	LoadCatalogTranslations(slog.Default(), rows)
	if got := quizCategoriesFor("missing")[0].Title; got != "Starters" {
		t.Fatalf("unknown language should fall back to English, got %q", got)
	}
}
