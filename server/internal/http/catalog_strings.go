package httpapi

// CatalogString is one translatable piece of text from the quiz/hwdykm/debate
// catalogs, addressed the same way content_translations rows are keyed.
// Exported for the offline catalog translation tooling, which enumerates these
// to drive translation.
type CatalogString struct {
	ContentType string `json:"contentType"` // "quiz_category" | "quiz" | "quiz_question" | "hwdykm_pack" | "hwdykm_question" | "debate_pack" | "debate_motion"
	ContentID   string `json:"contentID"`
	Field       string `json:"field"` // "title" | "prompt" | "option:<optionID>"
	Text        string `json:"text"` // English source text
	// Group batches related strings for translation context — e.g. every
	// string in one quiz category, so a batch call sees the whole category's
	// tone at once rather than one isolated question.
	Group string `json:"group"`
}

// CatalogStrings enumerates every translatable string across the three
// static content catalogs. The closed set of Tag values (CUTE/FUN/DEEP/18+/
// WEDDING) is intentionally excluded — those are ordinary UI strings (see
// internal/i18n), translated once and shared across every item that carries
// that tag, not duplicated per item here.
func CatalogStrings() []CatalogString {
	var out []CatalogString

	for _, cat := range quizCatalog {
		out = append(out, CatalogString{ContentType: "quiz_category", ContentID: cat.ID, Field: "title", Text: cat.Title, Group: cat.ID})
		for _, quiz := range cat.Quizzes {
			out = append(out, CatalogString{ContentType: "quiz", ContentID: quiz.ID, Field: "title", Text: quiz.Title, Group: cat.ID})
			for _, q := range quiz.Questions {
				out = append(out, CatalogString{ContentType: "quiz_question", ContentID: q.ID, Field: "prompt", Text: q.Prompt, Group: cat.ID})
				for _, o := range q.Options {
					out = append(out, CatalogString{ContentType: "quiz_question", ContentID: q.ID, Field: "option:" + o.ID, Text: o.Label, Group: cat.ID})
				}
			}
		}
	}

	for _, pack := range hwdykmPacks {
		out = append(out, CatalogString{ContentType: "hwdykm_pack", ContentID: pack.ID, Field: "title", Text: pack.Title, Group: pack.ID})
		for _, q := range pack.Questions {
			out = append(out, CatalogString{ContentType: "hwdykm_question", ContentID: q.ID, Field: "prompt", Text: q.Prompt, Group: pack.ID})
			for _, o := range q.Options {
				out = append(out, CatalogString{ContentType: "hwdykm_question", ContentID: q.ID, Field: "option:" + o.ID, Text: o.Label, Group: pack.ID})
			}
		}
	}

	for _, pack := range debatePacks {
		out = append(out, CatalogString{ContentType: "debate_pack", ContentID: pack.ID, Field: "title", Text: pack.Title, Group: pack.ID})
		for _, m := range pack.Motions {
			out = append(out, CatalogString{ContentType: "debate_motion", ContentID: m.ID, Field: "prompt", Text: m.Prompt, Group: pack.ID})
		}
	}

	return out
}
