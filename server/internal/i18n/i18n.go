// Package i18n serves the app's UI string translations. Values are embedded
// in the binary (translations.json, generated once from the iOS String
// Catalog plus a locally generated fill for languages it didn't yet cover)
// rather than stored in Postgres: at this scale
// (a few thousand short strings) embedding is simpler than a DB round trip,
// and "seed data baked into the binary" already matches how this codebase
// treats the quiz/hwdykm/debate catalogs.
package i18n

import (
	"embed"
	"encoding/json"
	"fmt"
)

//go:embed translations.json
var translationsFile embed.FS

// table maps language code -> UI string key -> translated value.
var table map[string]map[string]string

func init() {
	raw, err := translationsFile.ReadFile("translations.json")
	if err != nil {
		panic(fmt.Errorf("i18n: read embedded translations.json: %w", err))
	}
	if err := json.Unmarshal(raw, &table); err != nil {
		panic(fmt.Errorf("i18n: parse embedded translations.json: %w", err))
	}
}

// Strings returns the full key -> value map for a language code, and whether
// that language exists at all. An unknown language returns (nil, false) —
// callers should fall back to "en" (which is always present) rather than
// error, since the client has its own English fallback too.
func Strings(lang string) (map[string]string, bool) {
	m, ok := table[lang]
	return m, ok
}

// Languages returns every language code with at least partial coverage.
func Languages() []string {
	out := make([]string, 0, len(table))
	for lang := range table {
		out = append(out, lang)
	}
	return out
}
