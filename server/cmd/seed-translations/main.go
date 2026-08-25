// Command seed-translations fills the content_translations table by asking
// Claude to translate every string returned by httpapi.CatalogStrings() into
// each of the app's supported target languages.
//
// It is idempotent: rows already present in the target language are skipped,
// so it is safe to rerun after adding a new pack or a new language.
//
// Usage:
//
//	ANTHROPIC_API_KEY=... DATABASE_URL=postgres://... \
//	  go run ./cmd/seed-translations [-langs it,es,fr] [-workers 8]
//
// Without -langs it targets every language in i18n.Languages() other than
// English. The tool is written to be resumable — run it, kill it, run it
// again, it picks up where it left off.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	httpapi "github.com/sharepact/us/internal/http"
	"github.com/sharepact/us/internal/i18n"
	"github.com/sharepact/us/internal/store"
)

const (
	anthropicURL     = "https://api.anthropic.com/v1/messages"
	anthropicVersion = "2023-06-01"
	// Haiku is fast and cheap; translation is well within its capabilities and
	// the alternative (Sonnet/Opus) makes 800+ calls prohibitively expensive.
	defaultModel = "claude-haiku-4-5-20251001"
)

type job struct {
	Group string
	Lang  string
	Items []httpapi.CatalogString
}

type translator struct {
	apiKey string
	model  string
	client *http.Client
	store  *store.Store
}

func main() {
	var (
		langsFlag = flag.String("langs", "", "comma-separated target languages (default: every supported language except English)")
		workers   = flag.Int("workers", 8, "parallel Claude API calls")
		model     = flag.String("model", defaultModel, "Anthropic model to use")
		dryRun    = flag.Bool("dry-run", false, "print what would be translated and exit")
	)
	flag.Parse()

	apiKey := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY"))
	if apiKey == "" {
		log.Fatal("ANTHROPIC_API_KEY not set")
	}
	dbURL := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if dbURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("db connect: %v", err)
	}
	defer pool.Close()

	st := store.New(pool)

	targetLangs := parseLangs(*langsFlag)
	log.Printf("targeting %d languages: %s", len(targetLangs), strings.Join(targetLangs, ", "))

	all := httpapi.CatalogStrings()
	byGroup := make(map[string][]httpapi.CatalogString)
	for _, s := range all {
		byGroup[s.Group] = append(byGroup[s.Group], s)
	}
	log.Printf("catalog: %d strings across %d groups", len(all), len(byGroup))

	existing, err := loadExistingKeys(ctx, st, targetLangs)
	if err != nil {
		log.Fatalf("load existing: %v", err)
	}
	log.Printf("existing translations in DB: %d rows across the target languages", len(existing))

	// Enumerate (group, lang) pairs that still have missing strings.
	var jobs []job
	for group, items := range byGroup {
		for _, lang := range targetLangs {
			missing := filterMissing(items, lang, existing)
			if len(missing) == 0 {
				continue
			}
			jobs = append(jobs, job{Group: group, Lang: lang, Items: missing})
		}
	}
	log.Printf("%d group/language jobs to run", len(jobs))
	if *dryRun {
		for _, j := range jobs {
			log.Printf("  %s / %s : %d strings", j.Group, j.Lang, len(j.Items))
		}
		return
	}

	t := &translator{
		apiKey: apiKey,
		model:  *model,
		client: &http.Client{Timeout: 90 * time.Second},
		store:  st,
	}

	work := make(chan job)
	var wg sync.WaitGroup
	var completed, failed int
	var mu sync.Mutex

	for i := 0; i < *workers; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := range work {
				if err := t.runJob(ctx, j); err != nil {
					log.Printf("[worker %d] FAIL %s/%s: %v", id, j.Group, j.Lang, err)
					mu.Lock()
					failed++
					mu.Unlock()
					continue
				}
				mu.Lock()
				completed++
				log.Printf("[worker %d] done %s/%s (%d strings) — progress %d/%d", id, j.Group, j.Lang, len(j.Items), completed+failed, len(jobs))
				mu.Unlock()
			}
		}(i)
	}
	for _, j := range jobs {
		work <- j
	}
	close(work)
	wg.Wait()

	log.Printf("finished. completed=%d failed=%d", completed, failed)
	if failed > 0 {
		os.Exit(1)
	}
}

func parseLangs(csv string) []string {
	if strings.TrimSpace(csv) != "" {
		parts := strings.Split(csv, ",")
		out := make([]string, 0, len(parts))
		for _, p := range parts {
			p = strings.TrimSpace(p)
			if p != "" && p != "en" {
				out = append(out, p)
			}
		}
		return out
	}
	all := i18n.Languages()
	out := make([]string, 0, len(all))
	for _, l := range all {
		if l != "en" {
			out = append(out, l)
		}
	}
	return out
}

// loadExistingKeys returns the set of "lang|contentType|contentID|field" keys
// that already have a non-empty value, so we skip re-translating them.
func loadExistingKeys(ctx context.Context, st *store.Store, langs []string) (map[string]bool, error) {
	rows, err := st.AllContentTranslations(ctx)
	if err != nil {
		return nil, err
	}
	wanted := make(map[string]bool, len(langs))
	for _, l := range langs {
		wanted[l] = true
	}
	out := make(map[string]bool, len(rows))
	for _, r := range rows {
		if !wanted[r.Lang] {
			continue
		}
		if strings.TrimSpace(r.Value) == "" {
			continue
		}
		out[r.Lang+"|"+r.ContentType+"|"+r.ContentID+"|"+r.Field] = true
	}
	return out, nil
}

func filterMissing(items []httpapi.CatalogString, lang string, existing map[string]bool) []httpapi.CatalogString {
	out := make([]httpapi.CatalogString, 0, len(items))
	for _, s := range items {
		key := lang + "|" + s.ContentType + "|" + s.ContentID + "|" + s.Field
		if !existing[key] {
			out = append(out, s)
		}
	}
	return out
}

// runJob translates one (group, lang) batch and writes the results.
func (t *translator) runJob(ctx context.Context, j job) error {
	translations, err := t.translate(ctx, j)
	if err != nil {
		return err
	}
	for _, s := range j.Items {
		v, ok := translations[itemKey(s)]
		if !ok || strings.TrimSpace(v) == "" {
			continue
		}
		if err := t.store.UpsertContentTranslation(ctx, store.ContentTranslation{
			ContentType: s.ContentType,
			ContentID:   s.ContentID,
			Field:       s.Field,
			Lang:        j.Lang,
			Value:       v,
		}); err != nil {
			return fmt.Errorf("upsert %s/%s/%s: %w", s.ContentType, s.ContentID, s.Field, err)
		}
	}
	return nil
}

func itemKey(s httpapi.CatalogString) string {
	return s.ContentType + "|" + s.ContentID + "|" + s.Field
}

type translateRequest struct {
	Model      string             `json:"model"`
	MaxTokens  int                `json:"max_tokens"`
	System     string             `json:"system"`
	Messages   []anthropicMessage `json:"messages"`
	Temperature float64           `json:"temperature"`
}

type anthropicMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type anthropicResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	StopReason string `json:"stop_reason"`
	Usage      struct {
		InputTokens  int `json:"input_tokens"`
		OutputTokens int `json:"output_tokens"`
	} `json:"usage"`
}

const systemPrompt = `You translate short strings for a couples app called "Us." — the tone is warm, playful, romantic, sometimes cheeky.
Input is a JSON array of items with "key" and "text" (English source).
Output ONLY a JSON object whose keys are the input "key" values and whose values are the translated strings for the requested language. No prose, no markdown, no extra keys.
Guidance:
- Preserve emoji and any printf-style tokens like %@, %1$@, %d exactly as-is.
- Keep the same rough length so buttons and labels still fit.
- Prefer the informal "you" (tu / du / tú …) — couples talk to each other, not to an institution.
- Translate quiz/game titles and questions naturally, not literally; keep them playful.
- For option labels ("Yes", "No", "Somewhat", etc.), use idiomatic short forms.
- Never leave any value in English unless it is a proper noun.`

func (t *translator) translate(ctx context.Context, j job) (map[string]string, error) {
	// Compact input JSON: one object per string. Keys are stable content
	// identifiers so we can map results back reliably.
	type item struct {
		Key  string `json:"key"`
		Text string `json:"text"`
	}
	inputs := make([]item, len(j.Items))
	for i, s := range j.Items {
		inputs[i] = item{Key: itemKey(s), Text: s.Text}
	}
	rawInput, err := json.Marshal(inputs)
	if err != nil {
		return nil, err
	}
	userMsg := fmt.Sprintf("Target language BCP-47 code: %q\n\nItems:\n%s\n\nRespond with the JSON object described in the system prompt.",
		j.Lang, string(rawInput))

	req := translateRequest{
		Model:       t.model,
		MaxTokens:   8192,
		System:      systemPrompt,
		Temperature: 0.4,
		Messages: []anthropicMessage{
			{Role: "user", Content: userMsg},
		},
	}
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, anthropicURL, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("content-type", "application/json")
	httpReq.Header.Set("x-api-key", t.apiKey)
	httpReq.Header.Set("anthropic-version", anthropicVersion)

	var (
		resp *http.Response
	)
	// Simple retry with backoff — the Anthropic API occasionally 5xx or rate
	// limits; a couple of retries keeps the batch alive.
	for attempt := 0; attempt < 4; attempt++ {
		resp, err = t.client.Do(httpReq)
		if err == nil && resp.StatusCode < 500 && resp.StatusCode != 429 {
			break
		}
		if resp != nil {
			resp.Body.Close()
		}
		wait := time.Duration(1<<attempt) * time.Second
		time.Sleep(wait)
	}
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		buf := new(strings.Builder)
		_, _ = fmt.Fprintf(buf, "http %d", resp.StatusCode)
		return nil, fmt.Errorf("%s", buf.String())
	}

	var out anthropicResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode: %w", err)
	}
	if len(out.Content) == 0 {
		return nil, fmt.Errorf("empty response")
	}

	// Concatenate any text blocks, then extract the JSON object.
	var text strings.Builder
	for _, c := range out.Content {
		if c.Type == "text" {
			text.WriteString(c.Text)
		}
	}
	obj, err := extractJSONObject(text.String())
	if err != nil {
		return nil, fmt.Errorf("parse translations: %w", err)
	}
	return obj, nil
}

// extractJSONObject pulls out the outermost {...} object from a string that
// might have prose or code fences around it, then decodes it into map[string]string.
func extractJSONObject(s string) (map[string]string, error) {
	start := strings.Index(s, "{")
	end := strings.LastIndex(s, "}")
	if start < 0 || end < 0 || end <= start {
		return nil, fmt.Errorf("no JSON object found in: %s", firstN(s, 200))
	}
	trimmed := s[start : end+1]
	out := make(map[string]string)
	if err := json.Unmarshal([]byte(trimmed), &out); err != nil {
		return nil, fmt.Errorf("unmarshal: %w: %s", err, firstN(trimmed, 200))
	}
	return out, nil
}

func firstN(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
