// Package judge scores a single round of Couples Debate: both partners answer
// the SAME prompt, and the judge says whose case was better — it never assigns
// opposite sides, because comparing answers to two different questions would
// tell the couple nothing.
//
// When an Anthropic API key is configured it asks Claude to judge; otherwise it
// falls back to a local heuristic so the game always works offline.
package judge

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/sharepact/us/internal/i18n"
)

// Verdict is one round's result. Scores are 0..10. Winner is "a", "b", or
// "tie", where a and b are the couple's two user ids in stable order — so the
// cached verdict reads the same on both partners' phones. These JSON tags
// double as the shape cached in game_sessions.state.
type Verdict struct {
	AScore int    `json:"aScore"`
	BScore int    `json:"bScore"`
	Winner string `json:"winner"`
	Reason string `json:"reason"`
}

// Judge scores debate rounds. The zero value is not usable — call New.
type Judge struct {
	apiKey string
	model  string
	client *http.Client
}

// New builds a judge. An empty apiKey means every Score call uses the heuristic.
func New(apiKey, model string) *Judge {
	if model == "" {
		model = "claude-opus-4-8"
	}
	return &Judge{
		apiKey: strings.TrimSpace(apiKey),
		model:  model,
		client: &http.Client{Timeout: 30 * time.Second},
	}
}

// Score judges one round: `prompt` is the question both partners answered, and
// argA/argB are their two answers to it. `lang` is the BCP-47 code of the
// couple's app language, so the verdict `reason` comes back in the language
// they're reading the game in (empty falls through to English). It never
// returns an error — any problem reaching or parsing the model degrades to the
// heuristic, so a verdict always exists.
func (j *Judge) Score(ctx context.Context, prompt, argA, argB, lang string) Verdict {
	if j.apiKey != "" {
		if v, ok := j.scoreWithClaude(ctx, prompt, argA, argB, lang); ok {
			return v
		}
	}
	return heuristic(prompt, argA, argB, lang)
}

// ---- Claude ----

const (
	anthropicURL     = "https://api.anthropic.com/v1/messages"
	anthropicVersion = "2023-06-01"
)

var verdictSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"aScore": map[string]any{"type": "integer"},
		"bScore": map[string]any{"type": "integer"},
		"winner": map[string]any{"type": "string", "enum": []string{"a", "b", "tie"}},
		"reason": map[string]any{"type": "string"},
	},
	"required":             []string{"aScore", "bScore", "winner", "reason"},
	"additionalProperties": false,
}

const judgeSystem = `You are the impartial judge of a lighthearted debate between two romantic partners.
Both answered the SAME prompt, each making their own case — they may take opposite positions or the same one; that is fine either way.
Score partner A and partner B from 0 to 10 on how persuasive, clear, and creative their case is — reward good reasoning, examples, and wit; do not reward length alone or anything mean-spirited, and never favour a position just because it is listed first.
Pick the better case, or "tie" if they are within a point of each other.
Keep the reason to one or two upbeat, playful sentences the couple will enjoy reading. Never take real relationship sides or give relationship advice.`

func (j *Judge) scoreWithClaude(ctx context.Context, topic, argA, argB, lang string) (Verdict, bool) {
	prompt := fmt.Sprintf(
		"Prompt both partners answered: %q\n\nPARTNER A:\n%s\n\nPARTNER B:\n%s\n\nScore both cases and say who argued it better.",
		topic, strings.TrimSpace(argA), strings.TrimSpace(argB))

	system := judgeSystem
	if normalized := strings.TrimSpace(lang); normalized != "" && normalized != "en" {
		// Force the verdict `reason` to land in the couple's app language even
		// when the debate answers themselves came in another language.
		system += fmt.Sprintf("\nWrite the `reason` field in the language with BCP-47 code %q. Everything else stays JSON.", normalized)
	}

	body := map[string]any{
		"model":      j.model,
		"max_tokens": 1024,
		"system":     system,
		"messages": []map[string]any{
			{"role": "user", "content": prompt},
		},
		"output_config": map[string]any{
			"format": map[string]any{"type": "json_schema", "schema": verdictSchema},
		},
	}
	text, ok := j.requestText(ctx, body)
	if !ok {
		return Verdict{}, false
	}
	var v Verdict
	if err := json.Unmarshal([]byte(text), &v); err != nil {
		return Verdict{}, false
	}
	return clamp(v), true
}

// requestText POSTs a Messages API request and returns the first text block.
// ok is false on any transport, status, refusal, or parse problem — callers
// then fall back to their offline path.
func (j *Judge) requestText(ctx context.Context, body map[string]any) (string, bool) {
	raw, err := json.Marshal(body)
	if err != nil {
		return "", false
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicURL, bytes.NewReader(raw))
	if err != nil {
		return "", false
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", j.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)

	resp, err := j.client.Do(req)
	if err != nil {
		return "", false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", false
	}
	var out struct {
		StopReason string `json:"stop_reason"`
		Content    []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", false
	}
	if out.StopReason == "refusal" {
		return "", false
	}
	for _, c := range out.Content {
		if c.Type == "text" && c.Text != "" {
			return c.Text, true
		}
	}
	return "", false
}

// ---- Heuristic fallback ----

// heuristic scores each case on substance signals: length within reason,
// reasoning connectives, concrete examples, and acknowledging the other side.
// Reason strings are localized via i18n so the offline path speaks the same
// language as the Claude one.
func heuristic(topic, argA, argB, lang string) Verdict {
	a := scoreText(argA)
	b := scoreText(argB)
	v := Verdict{AScore: a, BScore: b}
	switch {
	case a-b >= 1:
		v.Winner = "a"
	case b-a >= 1:
		v.Winner = "b"
	default:
		v.Winner = "tie"
	}
	if v.Winner == "tie" {
		v.Reason = localizedReason(lang, "Too close to call — you both made a strong case. It's a tie! 🤝")
	} else {
		// The app names the winner; the reason stays about the argument itself,
		// since "a" and "b" mean nothing to the couple reading it.
		v.Reason = localizedReason(lang, "This one landed harder — clearer points and more to back them up. Nicely argued! 🏆")
	}
	return v
}

// localizedReason resolves a fallback verdict string against the shared UI
// translation table so the offline path matches the app language. Unknown
// language or missing key falls through to the English source string.
func localizedReason(lang, source string) string {
	lang = strings.TrimSpace(lang)
	if lang == "" || lang == "en" {
		return source
	}
	table, ok := i18n.Strings(lang)
	if !ok {
		return source
	}
	if v, present := table[source]; present && v != "" {
		return v
	}
	return source
}

func scoreText(s string) int {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	lower := strings.ToLower(s)
	words := len(strings.Fields(s))

	score := 3.0
	// Reward getting to a reasonable length (peaks around 40 words).
	score += math.Min(float64(words), 40) / 12
	// Reasoning connectives.
	for _, kw := range []string{"because", "since", "therefore", "so ", "reason", "which means"} {
		if strings.Contains(lower, kw) {
			score += 0.8
			break
		}
	}
	// Concrete illustration.
	for _, kw := range []string{"example", "for instance", "like ", "such as", "imagine"} {
		if strings.Contains(lower, kw) {
			score += 0.8
			break
		}
	}
	// Engaging the other side.
	for _, kw := range []string{"however", "but ", "although", "even if", "sure,", "admittedly"} {
		if strings.Contains(lower, kw) {
			score += 0.8
			break
		}
	}
	if strings.Contains(s, "?") { // a rhetorical question shows engagement
		score += 0.3
	}
	if words < 4 { // one-liners get penalised
		score -= 1.5
	}
	return clampScore(int(math.Round(score)))
}

func clamp(v Verdict) Verdict {
	v.AScore = clampScore(v.AScore)
	v.BScore = clampScore(v.BScore)
	if v.Winner != "a" && v.Winner != "b" && v.Winner != "tie" {
		switch {
		case v.AScore > v.BScore:
			v.Winner = "a"
		case v.BScore > v.AScore:
			v.Winner = "b"
		default:
			v.Winner = "tie"
		}
	}
	return v
}

func clampScore(n int) int {
	if n < 0 {
		return 0
	}
	if n > 10 {
		return 10
	}
	return n
}
