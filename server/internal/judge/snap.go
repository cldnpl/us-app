package judge

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
)

// SnapImage is one photo to judge in a Snap Hunt round.
type SnapImage struct {
	Data      []byte
	MediaType string // e.g. "image/jpeg"
}

// SnapVerdict is the outcome of a Snap Hunt round. Winner is "a", "b", or "tie".
type SnapVerdict struct {
	Winner string `json:"winner"`
	Reason string `json:"reason"`
}

var snapSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"winner": map[string]any{"type": "string", "enum": []string{"a", "b", "tie"}},
		"reason": map[string]any{"type": "string"},
	},
	"required":             []string{"winner", "reason"},
	"additionalProperties": false,
}

const snapSystem = `You are the playful judge of a photo scavenger hunt between two romantic partners.
They were each given the same loose clue and snapped a photo of something in their home that fits it.
Crown the cleverest, most creative, best-fitting find — reward wit, originality, and how well the object matches the clue, NOT photo quality or lighting.
Choose "a" or "b", or "tie" if they are equally good.
Keep the reason to one or two upbeat, playful sentences the couple will enjoy. Never be mean or judge the people in the photos.`

// ScoreSnaps judges two Snap Hunt photos against a clue. It never errors: with
// no API key (or any failure) it declares a tie, since cleverness can't be
// assessed offline.
func (j *Judge) ScoreSnaps(ctx context.Context, clue string, a, b SnapImage) SnapVerdict {
	if j.apiKey != "" {
		if v, ok := j.snapWithClaude(ctx, clue, a, b); ok {
			return v
		}
	}
	return SnapVerdict{Winner: "tie", Reason: "Two brilliant finds — the judge can't pick a favourite. It's a tie! 🤝"}
}

func imageBlock(img SnapImage) map[string]any {
	mt := img.MediaType
	if mt == "" {
		mt = "image/jpeg"
	}
	return map[string]any{
		"type": "image",
		"source": map[string]any{
			"type":       "base64",
			"media_type": mt,
			"data":       base64.StdEncoding.EncodeToString(img.Data),
		},
	}
}

func (j *Judge) snapWithClaude(ctx context.Context, clue string, a, b SnapImage) (SnapVerdict, bool) {
	text := fmt.Sprintf("Clue: %q\nPhoto A is the first image, Photo B is the second. Which find is cleverest? Pick a, b, or tie, and say why.", clue)
	body := map[string]any{
		"model":      j.model,
		"max_tokens": 1024,
		"system":     snapSystem,
		"messages": []map[string]any{
			{"role": "user", "content": []map[string]any{
				{"type": "text", "text": text},
				imageBlock(a),
				imageBlock(b),
			}},
		},
		"output_config": map[string]any{
			"format": map[string]any{"type": "json_schema", "schema": snapSchema},
		},
	}
	out, ok := j.requestText(ctx, body)
	if !ok {
		return SnapVerdict{}, false
	}
	var v SnapVerdict
	if err := json.Unmarshal([]byte(out), &v); err != nil {
		return SnapVerdict{}, false
	}
	if v.Winner != "a" && v.Winner != "b" && v.Winner != "tie" {
		v.Winner = "tie"
	}
	return v, true
}
