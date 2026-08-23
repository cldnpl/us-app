// Command translate-ui-strings is a one-off, safely-rerunnable tool that
// fills gaps in internal/i18n/translations.json using the Claude API (same
// request pattern as internal/judge — see judge.go). Only keys missing for a
// given language are translated; existing values are never overwritten, so
// it's safe to rerun after new UI strings are added to Localizable.xcstrings
// and re-extracted.
//
// Usage: ANTHROPIC_API_KEY=... go run ./cmd/translate-ui-strings [-model=claude-opus-4-8]
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
	"time"
)

const (
	anthropicURL     = "https://api.anthropic.com/v1/messages"
	anthropicVersion = "2023-06-01"
	translationsPath = "internal/i18n/translations.json"
)

// languageNames gives the model an unambiguous target language instead of a
// bare BCP-47 code (e.g. "fil" is not obviously "Filipino").
var languageNames = map[string]string{
	"ar": "Arabic", "bn": "Bengali", "da": "Danish", "de": "German",
	"es": "Spanish", "fa": "Persian (Farsi)", "fil": "Filipino (Tagalog)",
	"fr": "French", "hi": "Hindi", "id": "Indonesian", "it": "Italian",
	"ja": "Japanese", "ko": "Korean", "nl": "Dutch", "pl": "Polish",
	"pt-BR": "Brazilian Portuguese", "ru": "Russian", "sw": "Swahili",
	"th": "Thai", "tr": "Turkish", "uk": "Ukrainian", "ur": "Urdu",
	"uz": "Uzbek", "vi": "Vietnamese", "zh-Hans": "Simplified Chinese",
}

const translateSystem = `You are localizing UI text for "Us." — a private couples app (shared journal, photo gallery, quizzes, cycle tracking). The tone is warm, casual, and modern, never corporate or stiff.
Translate each given English UI string into the target language. Keep translations short and natural for mobile UI (buttons, labels, headers) — prioritize how a native speaker would actually phrase it in an app, not a literal word-for-word translation.
Preserve any placeholders exactly as written (e.g. %@, %d, {name}).
Return a JSON object with exactly the same keys you were given, each mapped to its translation.`

func main() {
	model := flag.String("model", "claude-opus-4-8", "Anthropic model id")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	if err := run(logger, *model); err != nil {
		logger.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger, model string) error {
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		return fmt.Errorf("ANTHROPIC_API_KEY is required")
	}

	raw, err := os.ReadFile(translationsPath)
	if err != nil {
		return fmt.Errorf("read %s: %w", translationsPath, err)
	}
	var table map[string]map[string]string
	if err := json.Unmarshal(raw, &table); err != nil {
		return fmt.Errorf("parse %s: %w", translationsPath, err)
	}

	en := table["en"]
	if len(en) == 0 {
		return fmt.Errorf("no english source strings found under \"en\"")
	}

	client := &http.Client{Timeout: 120 * time.Second}
	ctx := context.Background()

	var langs []string
	for lang := range table {
		if lang != "en" {
			langs = append(langs, lang)
		}
	}
	sort.Strings(langs)

	for _, lang := range langs {
		existing := table[lang]
		missing := map[string]string{} // key -> english source text
		for key, sourceText := range en {
			if _, ok := existing[key]; !ok {
				missing[key] = sourceText
			}
		}
		if len(missing) == 0 {
			logger.Info("up to date, skipping", "lang", lang)
			continue
		}
		logger.Info("translating", "lang", lang, "missing", len(missing))

		translated, err := translateBatch(ctx, client, apiKey, model, lang, missing)
		if err != nil {
			logger.Error("translate batch failed — leaving language as-is", "lang", lang, "err", err)
			continue
		}

		got := 0
		for key := range missing {
			if v, ok := translated[key]; ok && v != "" {
				existing[key] = v
				got++
			}
		}
		table[lang] = existing
		logger.Info("done", "lang", lang, "translated", got, "requested", len(missing))

		// Write after every language so a crash/interrupt partway through
		// doesn't lose already-translated languages.
		if err := writeTable(table); err != nil {
			return fmt.Errorf("write %s: %w", translationsPath, err)
		}
	}
	return nil
}

func translateBatch(ctx context.Context, client *http.Client, apiKey, model, lang string, missing map[string]string) (map[string]string, error) {
	name := languageNames[lang]
	if name == "" {
		name = lang
	}

	sourceJSON, err := json.Marshal(missing)
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

func writeTable(table map[string]map[string]string) error {
	raw, err := json.Marshal(table)
	if err != nil {
		return err
	}
	return os.WriteFile(translationsPath, raw, 0o644)
}
