// Command translate is a one-off, safely-rerunnable batch tool that fills
// content_translations for the quiz/hwdykm/debate catalogs (see
// internal/http/catalog_strings.go) using the Claude API — same request
// pattern as internal/judge (see judge.go). Only (contentID, field, lang)
// combinations missing from the table are translated, so an interrupted run
// can be restarted without re-spending on rows already done, and catalog
// content added later only costs API calls for the new strings.
//
// Requires Phase 0 (stable option ids) to already be live — option labels are
// translated here, and the app matches quiz/hwdykm answers by option id
// specifically so that translating labels never breaks matching.
//
// Usage: ANTHROPIC_API_KEY=... DATABASE_URL=... go run ./cmd/translate \
//
//	[-model=claude-opus-4-8] [-langs=es,fr,...] [-groups=starters,favorites,...]
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/sharepact/us/internal/config"
	"github.com/sharepact/us/internal/db"
	httpapi "github.com/sharepact/us/internal/http"
	"github.com/sharepact/us/internal/store"
)

const (
	anthropicURL     = "https://api.anthropic.com/v1/messages"
	anthropicVersion = "2023-06-01"
)

// languageNames gives the model an unambiguous target language instead of a
// bare BCP-47 code (e.g. "fil" is not obviously "Filipino"). Kept in sync
// with cmd/translate-ui-strings's list — same 25 non-English app languages.
var languageNames = map[string]string{
	"ar": "Arabic", "bn": "Bengali", "da": "Danish", "de": "German",
	"es": "Spanish", "fa": "Persian (Farsi)", "fil": "Filipino (Tagalog)",
	"fr": "French", "hi": "Hindi", "id": "Indonesian", "it": "Italian",
	"ja": "Japanese", "ko": "Korean", "nl": "Dutch", "pl": "Polish",
	"pt-BR": "Brazilian Portuguese", "ru": "Russian", "sw": "Swahili",
	"th": "Thai", "tr": "Turkish", "uk": "Ukrainian", "ur": "Urdu",
	"uz": "Uzbek", "vi": "Vietnamese", "zh-Hans": "Simplified Chinese",
}

const translateSystem = `You are localizing game content for "Us." — a private couples app. The content is quiz questions, "how well do you know me" questions, and lighthearted debate prompts, all meant to spark conversation between partners. The tone is warm, playful, and casual — never corporate or stiff.
Translate each given English string into the target language, keeping it natural for how a native speaker would actually phrase it — not a literal word-for-word translation. Short option labels (often with an emoji) should read as a native speaker would casually name that choice.
Preserve any emoji exactly as given, in a natural position for the target language.
Return a JSON object with exactly the same keys you were given, each mapped to its translation.`

func main() {
	model := flag.String("model", "claude-opus-4-8", "Anthropic model id")
	langsFlag := flag.String("langs", "", "comma-separated language codes to translate (default: all)")
	groupsFlag := flag.String("groups", "", "comma-separated group ids to translate (default: all) — mainly for smoke-testing a small slice")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	if err := run(logger, *model, *langsFlag, *groupsFlag); err != nil {
		logger.Error("fatal", "err", err)
		os.Exit(1)
	}
}

// groupKey uniquely identifies one CatalogString within a translation batch.
func groupKey(s httpapi.CatalogString) string { return s.ContentID + "::" + s.Field }

func translationDoneKey(lang string, s httpapi.CatalogString) string {
	return lang + "|" + s.ContentType + "|" + s.ContentID + "|" + s.Field
}

func run(logger *slog.Logger, model, langsFlag, groupsFlag string) error {
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		return fmt.Errorf("ANTHROPIC_API_KEY is required")
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	ctx := context.Background()

	pool, err := db.Connect(ctx, cfg.DatabaseURL, logger)
	if err != nil {
		return err
	}
	defer pool.Close()
	st := store.New(pool)

	existing, err := st.AllContentTranslations(ctx)
	if err != nil {
		return fmt.Errorf("load existing content_translations: %w", err)
	}
	done := make(map[string]bool, len(existing)) // "lang|contentType|contentID|field"
	for _, t := range existing {
		done[t.Lang+"|"+t.ContentType+"|"+t.ContentID+"|"+t.Field] = true
	}

	all := httpapi.CatalogStrings()
	if groupsFlag != "" {
		wanted := splitSet(groupsFlag)
		filtered := all[:0]
		for _, s := range all {
			if wanted[s.Group] {
				filtered = append(filtered, s)
			}
		}
		all = filtered
	}

	byGroup := map[string][]httpapi.CatalogString{}
	var groupOrder []string
	for _, s := range all {
		if _, ok := byGroup[s.Group]; !ok {
			groupOrder = append(groupOrder, s.Group)
		}
		byGroup[s.Group] = append(byGroup[s.Group], s)
	}
	sort.Strings(groupOrder)

	var langs []string
	if langsFlag != "" {
		for lang := range splitSet(langsFlag) {
			langs = append(langs, lang)
		}
	} else {
		for lang := range languageNames {
			langs = append(langs, lang)
		}
	}
	sort.Strings(langs)

	client := &http.Client{Timeout: 120 * time.Second}

	var totalTranslated, totalSkippedGroups int
	for _, lang := range langs {
		for _, group := range groupOrder {
			items := byGroup[group]
			missing := make([]httpapi.CatalogString, 0, len(items))
			for _, s := range items {
				if !done[translationDoneKey(lang, s)] {
					missing = append(missing, s)
				}
			}
			if len(missing) == 0 {
				totalSkippedGroups++
				continue
			}
			logger.Info("translating group", "lang", lang, "group", group, "missing", len(missing))

			source := make(map[string]string, len(missing))
			for _, s := range missing {
				source[groupKey(s)] = s.Text
			}
			translated, err := translateBatch(ctx, client, apiKey, model, lang, source)
			if err != nil {
				logger.Error("translate batch failed — leaving group as-is", "lang", lang, "group", group, "err", err)
				continue
			}

			for _, s := range missing {
				value, ok := translated[groupKey(s)]
				if !ok || value == "" {
					continue
				}
				if err := st.UpsertContentTranslation(ctx, store.ContentTranslation{
					ContentType: s.ContentType, ContentID: s.ContentID, Field: s.Field, Lang: lang, Value: value,
				}); err != nil {
					return fmt.Errorf("upsert %s/%s/%s/%s: %w", s.ContentType, s.ContentID, s.Field, lang, err)
				}
				done[translationDoneKey(lang, s)] = true
				totalTranslated++
			}
		}
	}

	logger.Info("done", "translated", totalTranslated, "groupsAlreadyComplete", totalSkippedGroups)
	return nil
}

func splitSet(csv string) map[string]bool {
	out := map[string]bool{}
	for _, part := range strings.Split(csv, ",") {
		part = strings.TrimSpace(part)
		if part != "" {
			out[part] = true
		}
	}
	return out
}

func translateBatch(ctx context.Context, client *http.Client, apiKey, model, lang string, source map[string]string) (map[string]string, error) {
	name := languageNames[lang]
	if name == "" {
		name = lang
	}
	sourceJSON, err := json.Marshal(source)
	if err != nil {
		return nil, err
	}

	schema := map[string]any{
		"type":                 "object",
		"additionalProperties": map[string]any{"type": "string"},
	}
	body := map[string]any{
		"model":      model,
		"max_tokens": 8192,
		"system":     translateSystem,
		"messages": []map[string]any{
			{"role": "user", "content": fmt.Sprintf("Target language: %s\n\nStrings to translate (JSON object, key -> English text):\n%s", name, sourceJSON)},
		},
		"output_config": map[string]any{
			"format": map[string]any{"type": "json_schema", "schema": schema},
		},
	}

	raw, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicURL, bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		var errBody bytes.Buffer
		errBody.ReadFrom(resp.Body)
		return nil, fmt.Errorf("status %d: %s", resp.StatusCode, errBody.String())
	}
	var out struct {
		StopReason string `json:"stop_reason"`
		Content    []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if out.StopReason == "refusal" {
		return nil, fmt.Errorf("model refused")
	}
	for _, c := range out.Content {
		if c.Type == "text" && c.Text != "" {
			var result map[string]string
			if err := json.Unmarshal([]byte(c.Text), &result); err != nil {
				return nil, fmt.Errorf("parse model output: %w", err)
			}
			return result, nil
		}
	}
	return nil, fmt.Errorf("no text content in response")
}
