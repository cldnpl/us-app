// Package judge scores a single round of Couples Debate: given a motion and the
// two sides' written cases, it returns a per-side score and a short verdict.
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
)

// Verdict is one round's result. Scores are 0..10. Winner is "for", "against",
// or "tie". These JSON tags double as the shape cached in game_sessions.state.
type Verdict struct {
	ForScore     int    `json:"forScore"`
	AgainstScore int    `json:"againstScore"`
	Winner       string `json:"winner"`
	Reason       string `json:"reason"`
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

// Score judges one round. It never returns an error: any problem reaching or
// parsing the model degrades to the heuristic, so a verdict always exists.
func (j *Judge) Score(ctx context.Context, motion, forArg, againstArg string) Verdict {
	if j.apiKey != "" {
		if v, ok := j.scoreWithClaude(ctx, motion, forArg, againstArg); ok {
			return v
		}
	}
	return heuristic(motion, forArg, againstArg)
}

// ---- Claude ----

const (
	anthropicURL     = "https://api.anthropic.com/v1/messages"
	anthropicVersion = "2023-06-01"
)

var verdictSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"forScore":     map[string]any{"type": "integer"},
		"againstScore": map[string]any{"type": "integer"},
		"winner":       map[string]any{"type": "string", "enum": []string{"for", "against", "tie"}},
		"reason":       map[string]any{"type": "string"},
	},
	"required":             []string{"forScore", "againstScore", "winner", "reason"},
	"additionalProperties": false,
}

const judgeSystem = `You are the impartial judge of a lighthearted debate between two romantic partners.
Score each side from 0 to 10 on how persuasive, clear, and creative their case is — reward good reasoning, examples, and wit; do not reward length alone or anything mean-spirited.
Pick the winning side, or "tie" if they are within a point of each other.
Keep the reason to one or two upbeat, playful sentences the couple will enjoy reading. Never take real relationship sides or give relationship advice.`

func (j *Judge) scoreWithClaude(ctx context.Context, motion, forArg, againstArg string) (Verdict, bool) {
	prompt := fmt.Sprintf(
		"Motion: %q\n\nFOR (arguing the motion is true):\n%s\n\nAGAINST (arguing the motion is false):\n%s\n\nScore both sides and crown a winner.",
		motion, strings.TrimSpace(forArg), strings.TrimSpace(againstArg))

	body := map[string]any{
		"model":      j.model,
		"max_tokens": 1024,
		"system":     judgeSystem,
		"messages": []map[string]any{
			{"role": "user", "content": prompt},
		},
		"output_config": map[string]any{
			"format": map[string]any{"type": "json_schema", "schema": verdictSchema},
		},
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return Verdict{}, false
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicURL, bytes.NewReader(raw))
	if err != nil {
		return Verdict{}, false
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", j.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)

	resp, err := j.client.Do(req)
	if err != nil {
		return Verdict{}, false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return Verdict{}, false
	}

	var out struct {
		StopReason string `json:"stop_reason"`
		Content    []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return Verdict{}, false
	}
	if out.StopReason == "refusal" {
		return Verdict{}, false
	}

	for _, c := range out.Content {
		if c.Type != "text" || c.Text == "" {
			continue
		}
		var v Verdict
		if err := json.Unmarshal([]byte(c.Text), &v); err != nil {
			return Verdict{}, false
		}
		return clamp(v), true
	}
	return Verdict{}, false
}

// ---- Heuristic fallback ----

// heuristic scores each case on substance signals: length within reason,
// reasoning connectives, concrete examples, and acknowledging the other side.
func heuristic(motion, forArg, againstArg string) Verdict {
	f := scoreText(forArg)
	a := scoreText(againstArg)
	v := Verdict{ForScore: f, AgainstScore: a}
	switch {
	case f-a >= 1:
		v.Winner = "for"
	case a-f >= 1:
		v.Winner = "against"
	default:
		v.Winner = "tie"
	}
	switch v.Winner {
	case "for":
		v.Reason = "The case for it landed harder — clearer points and more to back them up. Nicely argued! 🏆"
	case "against":
		v.Reason = "The case against it won the round — sharper reasoning and better examples. Well played! 🏆"
	default:
		v.Reason = "Too close to call — you both made a strong case. It's a tie! 🤝"
	}
	return v
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
	v.ForScore = clampScore(v.ForScore)
	v.AgainstScore = clampScore(v.AgainstScore)
	if v.Winner != "for" && v.Winner != "against" && v.Winner != "tie" {
		switch {
		case v.ForScore > v.AgainstScore:
			v.Winner = "for"
		case v.AgainstScore > v.ForScore:
			v.Winner = "against"
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
