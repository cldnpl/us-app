// Package generator asks Claude for fresh game content — debate motions,
// multiple-choice "how well do you know me" questions, quiz questions — so that
// a couple who has finished a pack can play again with material they haven't
// seen before. Every call has a hard offline fallback: an empty API key, a
// network error, or a bad response degrades to the passed-in seed catalog so
// the app never dead-ends when Anthropic is unreachable.
package generator

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	anthropicURL     = "https://api.anthropic.com/v1/messages"
	anthropicVersion = "2023-06-01"
)

// Generator is stateless; New builds one bound to an API key + model. An empty
// key means every call takes the offline path.
type Generator struct {
	apiKey string
	model  string
	client *http.Client
}

func New(apiKey, model string) *Generator {
	if strings.TrimSpace(model) == "" {
		model = "claude-opus-4-8"
	}
	return &Generator{
		apiKey: strings.TrimSpace(apiKey),
		model:  model,
		client: &http.Client{Timeout: 40 * time.Second},
	}
}

// DebatePrompts asks Claude for `count` fresh debate motions in the theme of
// `packTitle` (e.g. "Hot Takes"), avoiding anything that echoes the prompts in
// `avoid`. Returns exactly `count` prompts; falls back to `fallback` on any
// failure.
func (g *Generator) DebatePrompts(ctx context.Context, packTitle, description string,
	count int, avoid []string, lang string, fallback []string) []string {

	if g.apiKey == "" || count <= 0 {
		return trimTo(fallback, count)
	}

	system := "You invent short, playful debate motions for a couples game. Each motion is one statement (max 90 characters) that two partners can each argue for or against — sit on the fence-worthy, not politically loaded, never mean-spirited or NSFW unless the theme explicitly asks for spicy takes. Return strict JSON."
	langLine := ""
	if lang != "" && lang != "en" {
		langLine = fmt.Sprintf("\nWrite every motion in the language with BCP-47 code %q.", lang)
	}
	avoidBlock := ""
	if len(avoid) > 0 {
		avoidBlock = "\nDo not repeat or paraphrase any of these: " + strings.Join(quoteList(avoid), ", ")
	}
	user := fmt.Sprintf(
		"Theme: %s. %s\nGive me exactly %d brand-new debate motions in this theme.%s%s\nReturn JSON of the form {\"motions\": [\"…\", \"…\"]}.",
		packTitle, description, count, avoidBlock, langLine,
	)

	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"motions": map[string]any{
				"type":     "array",
				"items":    map[string]any{"type": "string"},
				"minItems": count,
				"maxItems": count,
			},
		},
		"required":             []string{"motions"},
		"additionalProperties": false,
	}
	var out struct {
		Motions []string `json:"motions"`
	}
	if !g.jsonCall(ctx, system, user, schema, &out) || len(out.Motions) < count {
		return trimTo(fallback, count)
	}
	return dedupTrim(out.Motions, count, fallback)
}

// HwdykmQuestion is one generated question with 3–4 stable-labelled options.
// Option IDs are stable slugs ("opt0"…) so answers stored under one round
// still resolve if wording is later tweaked.
type HwdykmQuestion struct {
	Prompt  string   `json:"prompt"`
	Options []string `json:"options"`
}

// HwdykmQuestions asks Claude for `count` fresh get-to-know-me questions in
// the theme of `packTitle`. Each question has 3–4 short, mutually exclusive
// options. Falls back to the seed pool on any failure.
func (g *Generator) HwdykmQuestions(ctx context.Context, packTitle, description string,
	count int, avoid []string, lang string, fallback []HwdykmQuestion) []HwdykmQuestion {

	if g.apiKey == "" || count <= 0 {
		return trimQuestions(fallback, count)
	}

	system := "You invent short, playful multiple-choice questions for the couples game \"How Well Do You Know Me\". Each question is one line about the subject's tastes / habits / vibes (max 60 characters) with 3 or 4 short, mutually exclusive options (each max 30 characters including any single emoji). Return strict JSON."
	langLine := ""
	if lang != "" && lang != "en" {
		langLine = fmt.Sprintf("\nWrite every prompt and every option in the language with BCP-47 code %q.", lang)
	}
	avoidBlock := ""
	if len(avoid) > 0 {
		avoidBlock = "\nDo not repeat or paraphrase any of these prompts: " + strings.Join(quoteList(avoid), ", ")
	}
	user := fmt.Sprintf(
		"Theme: %s. %s\nGive me exactly %d brand-new questions in this theme.%s%s\nReturn JSON of the form {\"questions\": [{\"prompt\": \"…\", \"options\": [\"…\", \"…\", \"…\"]}]}.",
		packTitle, description, count, avoidBlock, langLine,
	)

	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"questions": map[string]any{
				"type":     "array",
				"minItems": count,
				"maxItems": count,
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"prompt": map[string]any{"type": "string"},
						"options": map[string]any{
							"type":     "array",
							"items":    map[string]any{"type": "string"},
							"minItems": 3,
							"maxItems": 4,
						},
					},
					"required":             []string{"prompt", "options"},
					"additionalProperties": false,
				},
			},
		},
		"required":             []string{"questions"},
		"additionalProperties": false,
	}
	var out struct {
		Questions []HwdykmQuestion `json:"questions"`
	}
	if !g.jsonCall(ctx, system, user, schema, &out) || len(out.Questions) < count {
		return trimQuestions(fallback, count)
	}
	// Sanitize option shape: 3-4 non-empty strings, prompt non-empty.
	clean := make([]HwdykmQuestion, 0, count)
	for _, q := range out.Questions {
		q.Prompt = strings.TrimSpace(q.Prompt)
		if q.Prompt == "" {
			continue
		}
		opts := make([]string, 0, len(q.Options))
		for _, o := range q.Options {
			o = strings.TrimSpace(o)
			if o != "" {
				opts = append(opts, o)
			}
		}
		if len(opts) < 3 {
			continue
		}
		if len(opts) > 4 {
			opts = opts[:4]
		}
		q.Options = opts
		clean = append(clean, q)
		if len(clean) == count {
			break
		}
	}
	if len(clean) < count {
		return trimQuestions(fallback, count)
	}
	return clean
}

// QuizQuestion is one generated quiz question. Type mirrors the catalog:
// "open" for free-text prompts, "choice" for multiple-choice. Options carry
// the plain labels — icons/photos from the original catalog are dropped from
// regenerated content (the LLM can't reliably match SF-Symbol / photo bank
// keywords), and the app already handles label-only rendering.
type QuizQuestion struct {
	Prompt  string   `json:"prompt"`
	Type    string   `json:"type"` // "open" | "choice"
	Options []string `json:"options,omitempty"`
}

// QuizQuestions asks Claude for `count` fresh questions in a given quiz's
// theme. `format` is the quiz style (thisOrThat, whichDoYouPrefer,
// deepConversation) which nudges tone. `seed` carries the current questions
// (used both as an "avoid" hint and as the offline fallback). Every returned
// question mirrors the shape of the corresponding seed slot: open stays open,
// choice stays choice with the same number of options.
func (g *Generator) QuizQuestions(ctx context.Context, quizTitle, format string,
	count int, seed []QuizQuestion, lang string) []QuizQuestion {

	if g.apiKey == "" || count <= 0 {
		return trimQuizQuestions(seed, count)
	}
	// Describe the shape slot-by-slot so the model preserves open vs. choice
	// and the choice option count. Empty seed falls back to plain open prompts.
	slots := make([]map[string]any, 0, count)
	avoid := make([]string, 0, count)
	for i := 0; i < count; i++ {
		var s QuizQuestion
		if i < len(seed) {
			s = seed[i]
			avoid = append(avoid, s.Prompt)
		}
		typ := s.Type
		if typ != "choice" {
			typ = "open"
		}
		slot := map[string]any{"index": i, "type": typ}
		if typ == "choice" {
			n := len(s.Options)
			if n < 2 {
				n = 3
			}
			slot["optionCount"] = n
		}
		slots = append(slots, slot)
	}

	system := "You invent short, playful questions for a couples quiz app. Prompts are one line (max 80 characters) about the couple, their tastes or their shared world. Never NSFW unless the theme explicitly asks for it, never mean-spirited, never politically loaded. Return strict JSON."
	langLine := ""
	if lang != "" && lang != "en" {
		langLine = fmt.Sprintf("\nWrite every prompt and every option in the language with BCP-47 code %q.", lang)
	}
	formatLine := ""
	if format != "" {
		formatLine = fmt.Sprintf("\nStyle: %q — tone should match that format.", format)
	}
	shapeJSON, _ := json.Marshal(slots)
	avoidBlock := ""
	if len(avoid) > 0 {
		avoidBlock = "\nDo not repeat or paraphrase any of these prompts: " + strings.Join(quoteList(avoid), ", ")
	}

	user := fmt.Sprintf(
		"Theme: %s.%s\nGenerate exactly %d brand-new questions.%s%s\nMatch this shape slot-by-slot — same index, same type; if a slot is type \"choice\", supply exactly `optionCount` short (max 30 chars) mutually exclusive options: %s\nReturn JSON of the form {\"questions\": [{\"prompt\": \"…\", \"type\": \"open\"|\"choice\", \"options\": [\"…\"]}]}.",
		quizTitle, formatLine, count, avoidBlock, langLine, string(shapeJSON),
	)

	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"questions": map[string]any{
				"type":     "array",
				"minItems": count,
				"maxItems": count,
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"prompt":  map[string]any{"type": "string"},
						"type":    map[string]any{"type": "string", "enum": []string{"open", "choice"}},
						"options": map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
					},
					"required":             []string{"prompt", "type"},
					"additionalProperties": false,
				},
			},
		},
		"required":             []string{"questions"},
		"additionalProperties": false,
	}
	var out struct {
		Questions []QuizQuestion `json:"questions"`
	}
	if !g.jsonCall(ctx, system, user, schema, &out) || len(out.Questions) < count {
		return trimQuizQuestions(seed, count)
	}
	clean := make([]QuizQuestion, 0, count)
	for i, q := range out.Questions {
		q.Prompt = strings.TrimSpace(q.Prompt)
		if q.Prompt == "" {
			continue
		}
		if q.Type != "choice" {
			q.Type = "open"
			q.Options = nil
		} else {
			opts := make([]string, 0, len(q.Options))
			for _, o := range q.Options {
				o = strings.TrimSpace(o)
				if o != "" {
					opts = append(opts, o)
				}
			}
			// Drop malformed choice questions rather than serving zero options.
			if len(opts) < 2 {
				continue
			}
			q.Options = opts
		}
		// Keep the shape aligned with the seed slot's type where possible —
		// falling back to whatever the model gave us if that slot's info is
		// missing (short seed).
		if i < len(seed) {
			if seed[i].Type == "choice" && q.Type == "open" {
				continue
			}
			if seed[i].Type == "open" && q.Type == "choice" {
				continue
			}
		}
		clean = append(clean, q)
		if len(clean) == count {
			break
		}
	}
	if len(clean) < count {
		return trimQuizQuestions(seed, count)
	}
	return clean
}

func trimQuizQuestions(items []QuizQuestion, n int) []QuizQuestion {
	if n <= 0 || len(items) == 0 {
		return nil
	}
	if len(items) >= n {
		return append([]QuizQuestion(nil), items[:n]...)
	}
	out := append([]QuizQuestion(nil), items...)
	for len(out) < n {
		out = append(out, items[len(items)-1])
	}
	return out
}

// ---- shared plumbing ----

func (g *Generator) jsonCall(ctx context.Context, system, user string, schema map[string]any, out any) bool {
	body := map[string]any{
		"model":      g.model,
		"max_tokens": 2048,
		"system":     system,
		"messages": []map[string]any{
			{"role": "user", "content": user},
		},
		"output_config": map[string]any{
			"format": map[string]any{"type": "json_schema", "schema": schema},
		},
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return false
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicURL, bytes.NewReader(raw))
	if err != nil {
		return false
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", g.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)

	resp, err := g.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false
	}
	var msg struct {
		StopReason string `json:"stop_reason"`
		Content    []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&msg); err != nil {
		return false
	}
	if msg.StopReason == "refusal" {
		return false
	}
	for _, c := range msg.Content {
		if c.Type != "text" || c.Text == "" {
			continue
		}
		if err := json.Unmarshal([]byte(c.Text), out); err == nil {
			return true
		}
	}
	return false
}

func quoteList(items []string) []string {
	out := make([]string, 0, len(items))
	for _, s := range items {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		out = append(out, fmt.Sprintf("%q", s))
	}
	return out
}

func trimTo(items []string, n int) []string {
	if n <= 0 || len(items) == 0 {
		return nil
	}
	if len(items) >= n {
		return append([]string(nil), items[:n]...)
	}
	// Pad by repeating the last entry so the caller always gets `n`. This is
	// intentionally simple: it only fires if the fallback catalog is too small
	// to fill a round, which is a content bug rather than user-visible flow.
	out := append([]string(nil), items...)
	for len(out) < n {
		out = append(out, items[len(items)-1])
	}
	return out
}

func trimQuestions(items []HwdykmQuestion, n int) []HwdykmQuestion {
	if n <= 0 || len(items) == 0 {
		return nil
	}
	if len(items) >= n {
		return append([]HwdykmQuestion(nil), items[:n]...)
	}
	out := append([]HwdykmQuestion(nil), items...)
	for len(out) < n {
		out = append(out, items[len(items)-1])
	}
	return out
}

func dedupTrim(items []string, n int, fallback []string) []string {
	seen := make(map[string]struct{}, n)
	out := make([]string, 0, n)
	for _, s := range items {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		key := strings.ToLower(s)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, s)
		if len(out) == n {
			return out
		}
	}
	// Backfill from fallback if Claude gave us fewer unique motions than asked.
	for _, s := range fallback {
		if len(out) == n {
			break
		}
		key := strings.ToLower(strings.TrimSpace(s))
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, s)
	}
	return trimTo(out, n)
}
