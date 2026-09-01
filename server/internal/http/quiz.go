package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/generator"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// ---- per-category generation ------------------------------------------------
//
// Every quiz category rotates independently. Once both partners have completed
// every quiz in a category, the category's generation bumps on their
// game_sessions row `quiz_cat:<catID>`, previously stored answers stop
// resolving, and on the next fetch each quiz in that category regenerates its
// questions via Claude (with the seed catalog as offline fallback). Fresh
// questions are cached per (category, generation, quiz) on the same row so
// callers pay the LLM cost at most once per quiz per rotation.
//
// Answer keys are composed as `qcat:<catID>:g<gen>:<quizID>`. For generation
// 1 we keep the raw quizID (no prefix) so existing rows written before
// rotation existed keep resolving without a migration.

func quizCatGameType(catID string) string { return "quiz_cat:" + catID }

type quizCategoryState struct {
	Generation int `json:"gen"`
	// Content maps quizID → generated questions for the current generation.
	// Populated lazily on the first fetch of each quiz after a bump.
	Content map[string][]generatedQuizQuestion `json:"content,omitempty"`
}

// generatedQuizQuestion mirrors the wire shape (open vs. choice, labels only)
// but with stable ids assigned once and reused across future fetches so
// quiz_answers rows can still find their question.
type generatedQuizQuestion struct {
	ID      string          `json:"id"`
	Prompt  string          `json:"prompt"`
	Type    string          `json:"type"` // "open" | "choice"
	Options []catalogOption `json:"options,omitempty"`
}

// loadQuizCategoryState fetches the couple's persisted state for a category —
// generation defaults to 1, content nil if never regenerated. sessionID is
// empty when no row exists yet.
func (d Deps) loadQuizCategoryState(ctx context.Context, coupleID, catID string) (quizCategoryState, string, error) {
	g, err := d.Store.GetLatestGame(ctx, coupleID, quizCatGameType(catID))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return quizCategoryState{Generation: 1}, "", nil
		}
		return quizCategoryState{Generation: 1}, "", err
	}
	var st quizCategoryState
	if len(g.State) > 0 {
		_ = json.Unmarshal(g.State, &st)
	}
	if st.Generation < 1 {
		st.Generation = 1
	}
	return st, g.ID, nil
}

func (d Deps) saveQuizCategoryState(ctx context.Context, coupleID, catID, sessionID string, st quizCategoryState) (string, error) {
	raw, _ := json.Marshal(st)
	if sessionID == "" {
		g, err := d.Store.CreateGame(ctx, coupleID, quizCatGameType(catID), raw, "")
		if err != nil {
			return "", err
		}
		return g.ID, nil
	}
	if _, err := d.Store.UpdateGame(ctx, sessionID, raw, nil, "active"); err != nil {
		return sessionID, err
	}
	return sessionID, nil
}

// bumpQuizCategoryGen increments the category's generation and clears its
// cached content, so the next fetch of any quiz in the category triggers a
// fresh LLM regeneration.
func (d Deps) bumpQuizCategoryGen(ctx context.Context, coupleID, catID, sessionID string, st quizCategoryState) (quizCategoryState, string, error) {
	st.Generation++
	if st.Generation < 1 {
		st.Generation = 1
	}
	st.Content = nil
	newID, err := d.saveQuizCategoryState(ctx, coupleID, catID, sessionID, st)
	return st, newID, err
}

// quizAnswerKey composes the DB key for a quiz's answers under the category's
// current generation. Generation 1 is unprefixed so pre-rotation rows resolve
// unchanged; from generation 2 onward the key encodes both the category and
// the generation so old answers linger without leaking into new rounds.
func quizAnswerKey(catID, quizID string, gen int) string {
	if gen <= 1 {
		return quizID
	}
	return fmt.Sprintf("qcat:%s:g%d:%s", catID, gen, quizID)
}

// resolveQuizQuestions returns the questions to serve for a specific quiz in a
// category. On generation 1 (or when Claude / storage isn't ready) it falls
// back to the seed catalog. On later generations it consults the cached
// per-(category, gen, quiz) content; if the cache is cold it asks Claude for
// a fresh set matching the seed's shape, persists, and returns them. Callers
// pass the already-loaded state so a single request doesn't re-hit the row.
func (d Deps) resolveQuizQuestions(ctx context.Context, coupleID, catID, sessionID string,
	st *quizCategoryState, quiz catalogQuiz, lang string) []catalogQuestion {

	if st.Generation <= 1 {
		return quiz.Questions
	}
	if cached, ok := st.Content[quiz.ID]; ok && len(cached) >= len(quiz.Questions) {
		return generatedToCatalog(cached)
	}

	// Ask Claude for a fresh set. Map the seed's shape (open vs choice, option
	// counts) so the regenerated quiz stays playable the same way.
	seed := make([]generator.QuizQuestion, 0, len(quiz.Questions))
	for _, q := range quiz.Questions {
		opts := make([]string, 0, len(q.Options))
		for _, o := range q.Options {
			opts = append(opts, o.Label)
		}
		seed = append(seed, generator.QuizQuestion{
			Prompt: q.Prompt, Type: string(q.Type), Options: opts,
		})
	}
	gen := generator.New(d.Config.AnthropicAPIKey, d.Config.AnthropicModel)
	fresh := gen.QuizQuestions(ctx, quiz.Title, string(quiz.Format), len(quiz.Questions), seed, lang)

	stored := make([]generatedQuizQuestion, 0, len(fresh))
	for i, q := range fresh {
		options := make([]catalogOption, 0, len(q.Options))
		for j, label := range q.Options {
			options = append(options, catalogOption{
				ID:    fmt.Sprintf("opt%d", j),
				Label: label,
			})
		}
		stored = append(stored, generatedQuizQuestion{
			ID:      fmt.Sprintf("%s_g%d_q%d", quiz.ID, st.Generation, i+1),
			Prompt:  q.Prompt,
			Type:    q.Type,
			Options: options,
		})
	}

	if st.Content == nil {
		st.Content = make(map[string][]generatedQuizQuestion)
	}
	st.Content[quiz.ID] = stored
	if newID, err := d.saveQuizCategoryState(ctx, coupleID, catID, sessionID, *st); err != nil {
		// Persist failed — still serve the freshly generated questions this
		// request; the next fetch will regenerate and try again to cache.
		d.Logger.Warn("quiz: cache regenerated content", "err", err, "cat", catID, "quiz", quiz.ID)
	} else if sessionID == "" {
		sessionID = newID
		_ = sessionID // keep for symmetry — caller isn't tracking the id back
	}
	return generatedToCatalog(stored)
}

func generatedToCatalog(qs []generatedQuizQuestion) []catalogQuestion {
	out := make([]catalogQuestion, 0, len(qs))
	for _, q := range qs {
		typ := qTypeOpen
		if q.Type == "choice" {
			typ = qTypeChoice
		}
		out = append(out, catalogQuestion{
			ID:      q.ID,
			Prompt:  q.Prompt,
			Type:    typ,
			Options: q.Options,
		})
	}
	return out
}

// resolveOptions maps catalog options to the wire shape, turning photo keywords
// into concrete image URLs (curated in photoURL). Unknown keywords drop the
// image so the app falls back to the icon rather than showing a wrong photo.
func resolveOptions(opts []catalogOption) []quizOptionView {
	out := make([]quizOptionView, 0, len(opts))
	for _, o := range opts {
		v := quizOptionView{ID: o.ID, Label: o.Label, Icon: o.Icon}
		if o.Image != "" {
			if url, ok := photoURL[o.Image]; ok {
				v.Image = url
			}
		}
		out = append(out, v)
	}
	return out
}

// ---- response shapes ----

type quizCategorySummary struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Icon      string `json:"icon"`
	ColorKey  string `json:"colorKey"`
	QuizCount int    `json:"quizCount"`
	// Quizzes each of us has finished, and how many are waiting on me because
	// my partner already answered them.
	CompletedCount        int `json:"completedCount"`
	PartnerCompletedCount int `json:"partnerCompletedCount"`
	YourTurnCount         int `json:"yourTurnCount"`
	// Progress is the *couple's*: a quiz only counts fully once both of us have
	// answered it, so one person finishing alone moves the bar half a quiz. That
	// way the bar reflects what the feature is for — comparing answers — instead
	// of hitting 100% while the other half is still unanswered.
	Progress   float64 `json:"progress"`   // 0..1, both of us
	MyProgress float64 `json:"myProgress"` // 0..1, mine alone
}

type quizSummary struct {
	ID            string `json:"id"`
	Title         string `json:"title"`
	Icon          string `json:"icon"`
	Format        string `json:"format"`
	Tag           string `json:"tag,omitempty"`
	QuestionCount int    `json:"questionCount"`
	MyDone        bool   `json:"myDone"`
	PartnerDone   bool   `json:"partnerDone"`
}

type quizCategoryDetail struct {
	ID       string        `json:"id"`
	Title    string        `json:"title"`
	Icon     string        `json:"icon"`
	ColorKey string        `json:"colorKey"`
	Quizzes  []quizSummary `json:"quizzes"`
}

type quizOptionView struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Icon  string `json:"icon,omitempty"`  // SF Symbol
	Image string `json:"image,omitempty"` // photo keyword
}

type quizQuestionView struct {
	ID            string           `json:"id"`
	Prompt        string           `json:"prompt"`
	Type          string           `json:"type"`
	Options       []quizOptionView `json:"options,omitempty"`
	MyAnswer      *string          `json:"myAnswer"`      // option id (choice) or free text (open)
	PartnerAnswer *string          `json:"partnerAnswer"` // revealed only after I answer this question
	// Whether my partner has answered, which the app can say ("your turn")
	// without revealing *what* they answered before I've answered myself.
	PartnerAnswered bool `json:"partnerAnswered"`
	BothAnswered    bool `json:"bothAnswered"`
}

type quizDetail struct {
	ID        string             `json:"id"`
	Title     string             `json:"title"`
	Icon      string             `json:"icon"`
	Format    string             `json:"format"`
	Tag       string             `json:"tag,omitempty"`
	Questions []quizQuestionView `json:"questions"`
}

// completionByUser maps quizID -> userID -> count of distinct questions answered.
func completionByUser(keys []store.QuizAnswerKey) map[string]map[string]int {
	m := make(map[string]map[string]int)
	for _, k := range keys {
		if m[k.QuizID] == nil {
			m[k.QuizID] = make(map[string]int)
		}
		m[k.QuizID][k.UserID]++
	}
	return m
}

func quizDone(counts map[string]map[string]int, quizID, userID string, total int) bool {
	return total > 0 && counts[quizID][userID] >= total
}

// ---- handlers ----

// GET /v1/quiz/categories — all categories with my progress.
func (d Deps) handleListQuizCategories(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	keys, err := d.Store.GetQuizAnswerKeys(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "quiz: keys", err)
		return
	}
	counts := completionByUser(keys)
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)

	categories := quizCategoriesFor(langParam(r))
	out := make([]quizCategorySummary, 0, len(categories))
	for _, cat := range categories {
		st, sessionID, lerr := d.loadQuizCategoryState(r.Context(), c.ID, cat.ID)
		if lerr != nil {
			d.serverError(w, "quiz: cat state", lerr)
			return
		}
		gen := st.Generation

		// Per-category rotation: once both partners have completed every quiz
		// in this category under `gen`, bump the generation. On the next fetch
		// the answer keys stop matching (progress resets to 0) and each quiz
		// regenerates its questions via Claude on first access.
		if partner.ID != "" {
			allDone := true
			for _, q := range cat.Quizzes {
				key := quizAnswerKey(cat.ID, q.ID, gen)
				if !quizDone(counts, key, userID, len(q.Questions)) ||
					!quizDone(counts, key, partner.ID, len(q.Questions)) {
					allDone = false
					break
				}
			}
			if allDone {
				bumped, _, berr := d.bumpQuizCategoryGen(r.Context(), c.ID, cat.ID, sessionID, st)
				if berr != nil {
					d.Logger.Warn("quiz: bump category", "err", berr, "cat", cat.ID)
				} else {
					gen = bumped.Generation
				}
			}
		}

		done, partnerDone, yourTurn := 0, 0, 0
		for _, q := range cat.Quizzes {
			key := quizAnswerKey(cat.ID, q.ID, gen)
			mine := quizDone(counts, key, userID, len(q.Questions))
			theirs := partner.ID != "" && quizDone(counts, key, partner.ID, len(q.Questions))
			if mine {
				done++
			}
			if theirs {
				partnerDone++
				if !mine {
					yourTurn++
				}
			}
		}
		myProgress, progress := 0.0, 0.0
		if n := len(cat.Quizzes); n > 0 {
			myProgress = float64(done) / float64(n)
			if partner.ID == "" {
				// Nobody to compare with yet — don't cap the bar at half.
				progress = myProgress
			} else {
				// Each quiz is worth two halves, one per person.
				progress = float64(done+partnerDone) / float64(2*n)
			}
		}
		_ = sessionID // reserved for future per-request coalescing
		out = append(out, quizCategorySummary{
			ID: cat.ID, Title: cat.Title, Icon: cat.Icon, ColorKey: cat.ColorKey,
			QuizCount: len(cat.Quizzes), CompletedCount: done,
			PartnerCompletedCount: partnerDone, YourTurnCount: yourTurn,
			Progress: progress, MyProgress: myProgress,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"categories": out})
}

// GET /v1/quiz/categories/{id} — quizzes in a category with per-quiz done flags.
func (d Deps) handleGetQuizCategory(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	catID := chi.URLParam(r, "id")
	var cat catalogCategory
	found := false
	for _, cc := range quizCategoriesFor(langParam(r)) {
		if cc.ID == catID {
			cat, found = cc, true
			break
		}
	}
	if !found {
		writeError(w, http.StatusNotFound, "unknown_category", "unknown category")
		return
	}

	st, sessionID, err := d.loadQuizCategoryState(r.Context(), c.ID, cat.ID)
	if err != nil {
		d.serverError(w, "quiz: cat state", err)
		return
	}
	gen := st.Generation
	keys, err := d.Store.GetQuizAnswerKeys(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "quiz: keys", err)
		return
	}
	counts := completionByUser(keys)
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)

	// Same rotation trigger as the categories list — the app might arrive here
	// straight from a deep link without a list refresh in between.
	if partner.ID != "" {
		allDone := true
		for _, q := range cat.Quizzes {
			key := quizAnswerKey(cat.ID, q.ID, gen)
			if !quizDone(counts, key, userID, len(q.Questions)) ||
				!quizDone(counts, key, partner.ID, len(q.Questions)) {
				allDone = false
				break
			}
		}
		if allDone {
			bumped, newID, berr := d.bumpQuizCategoryGen(r.Context(), c.ID, cat.ID, sessionID, st)
			if berr != nil {
				d.Logger.Warn("quiz: bump category", "err", berr, "cat", cat.ID)
			} else {
				st = bumped
				gen = st.Generation
				sessionID = newID
			}
		}
	}

	_ = sessionID
	quizzes := make([]quizSummary, 0, len(cat.Quizzes))
	for _, q := range cat.Quizzes {
		total := len(q.Questions)
		key := quizAnswerKey(cat.ID, q.ID, gen)
		quizzes = append(quizzes, quizSummary{
			ID: q.ID, Title: q.Title, Icon: q.Icon, Format: string(q.Format), Tag: q.Tag,
			QuestionCount: total,
			MyDone:        quizDone(counts, key, userID, total),
			PartnerDone:   partner.ID != "" && quizDone(counts, key, partner.ID, total),
		})
	}
	writeJSON(w, http.StatusOK, quizCategoryDetail{
		ID: cat.ID, Title: cat.Title, Icon: cat.Icon, ColorKey: cat.ColorKey, Quizzes: quizzes,
	})
}

// GET /v1/quiz/{quizId} — questions with my answers and (once I've answered) my partner's.
func (d Deps) handleGetQuiz(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	quizID := chi.URLParam(r, "quizId")
	cat, quiz, found := findQuizAndCategoryIn(quizCategoriesFor(langParam(r)), quizID)
	if !found {
		writeError(w, http.StatusNotFound, "unknown_quiz", "unknown quiz")
		return
	}
	st, sessionID, gerr := d.loadQuizCategoryState(r.Context(), c.ID, cat.ID)
	if gerr != nil {
		d.serverError(w, "quiz: cat state", gerr)
		return
	}
	// On generations past the first, questions come from the LLM-generated
	// cache — regenerated on first fetch after each bump.
	questions := d.resolveQuizQuestions(r.Context(), c.ID, cat.ID, sessionID, &st, quiz, langParam(r))
	key := quizAnswerKey(cat.ID, quizID, st.Generation)

	answers, err := d.Store.GetQuizAnswers(r.Context(), c.ID, key)
	if err != nil {
		d.serverError(w, "quiz: answers", err)
		return
	}
	// index answers per question
	mine := make(map[string]string)
	theirs := make(map[string]string)
	for _, a := range answers {
		if a.UserID == userID {
			mine[a.QuestionID] = a.Answer
		} else {
			theirs[a.QuestionID] = a.Answer
		}
	}

	views := make([]quizQuestionView, 0, len(questions))
	for _, q := range questions {
		v := quizQuestionView{ID: q.ID, Prompt: q.Prompt, Type: string(q.Type), Options: resolveOptions(q.Options)}
		myAns, iAnswered := mine[q.ID]
		partnerAns, theyAnswered := theirs[q.ID]
		if iAnswered {
			v.MyAnswer = &myAns
			if theyAnswered { // reveal partner only after I've answered this one
				pa := partnerAns
				v.PartnerAnswer = &pa
			}
		}
		v.PartnerAnswered = theyAnswered
		v.BothAnswered = iAnswered && theyAnswered
		views = append(views, v)
	}
	writeJSON(w, http.StatusOK, quizDetail{
		ID: quiz.ID, Title: quiz.Title, Icon: quiz.Icon, Format: string(quiz.Format), Tag: quiz.Tag, Questions: views,
	})
}

type quizAnswerRequest struct {
	QuestionID string `json:"questionId"`
	Answer     string `json:"answer"`
}

// POST /v1/quiz/{quizId}/answer — save one answer, notify partner.
func (d Deps) handleAnswerQuiz(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	quizID := chi.URLParam(r, "quizId")
	cat, quiz, found := findQuizAndCategoryIn(quizCatalog, quizID)
	if !found {
		writeError(w, http.StatusNotFound, "unknown_quiz", "unknown quiz")
		return
	}
	var req quizAnswerRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	answer := strings.TrimSpace(req.Answer)
	if answer == "" {
		writeError(w, http.StatusBadRequest, "empty", "pick or write an answer first")
		return
	}
	st, sessionID, gerr := d.loadQuizCategoryState(r.Context(), c.ID, cat.ID)
	if gerr != nil {
		d.serverError(w, "quiz: cat state", gerr)
		return
	}
	// Validate the answer against the actual live question set for this
	// generation — the regenerated question IDs won't match the seed catalog.
	questions := d.resolveQuizQuestions(r.Context(), c.ID, cat.ID, sessionID, &st, quiz, langParam(r))
	var question *catalogQuestion
	for i := range questions {
		if questions[i].ID == req.QuestionID {
			question = &questions[i]
			break
		}
	}
	if question == nil {
		writeError(w, http.StatusBadRequest, "unknown_question", "unknown question")
		return
	}
	if question.Type == qTypeChoice {
		validOption := false
		for _, o := range question.Options {
			if o.ID == answer {
				validOption = true
				break
			}
		}
		if !validOption {
			writeError(w, http.StatusBadRequest, "unknown_option", "unknown option")
			return
		}
	}
	key := quizAnswerKey(cat.ID, quizID, st.Generation)
	if err := d.Store.UpsertQuizAnswer(r.Context(), c.ID, key, req.QuestionID, userID, answer); err != nil {
		d.serverError(w, "quiz: save", err)
		return
	}
	d.notifyTurnOrResults(r.Context(), c.ID, userID, key, quiz.Title, len(questions),
		"You've both answered — see how you compare 💛",
		map[string]string{"type": "quiz", "quizId": quizID})
	w.WriteHeader(http.StatusNoContent)
}

// ---- Question of the Day ----
//
// A single question that rotates every day: the category advances by one each
// day (so a different colour/topic daily), and the question within cycles over
// time. Deterministic from the date, so both partners get the same one.

type dailyQuestionResponse struct {
	Date          string           `json:"date"`
	CategoryID    string           `json:"categoryId"`
	CategoryTitle string           `json:"categoryTitle"`
	ColorKey      string           `json:"colorKey"`
	Icon          string           `json:"icon"`
	QuizTitle     string           `json:"quizTitle"`
	Question      quizQuestionView `json:"question"`
}

// dailyPick returns the category, quiz and question for a given day, chosen
// from categories. The day-index math only depends on category/question
// counts, which are identical between the English catalog and any of its
// localized copies (same structure, translated text) — so callers pass
// quizCatalog for id-only validation or quizCategoriesFor(lang) for display,
// and always land on the same logical question either way.
func dailyPick(t time.Time, categories []catalogCategory) (catalogCategory, catalogQuiz, catalogQuestion) {
	day := int(t.Unix() / 86400) // days since epoch (UTC)
	cat := categories[((day%len(categories))+len(categories))%len(categories)]
	type qp struct {
		quiz catalogQuiz
		q    catalogQuestion
	}
	var all []qp
	for _, quiz := range cat.Quizzes {
		for _, q := range quiz.Questions {
			all = append(all, qp{quiz, q})
		}
	}
	pick := all[(day/len(categories))%len(all)]
	return cat, pick.quiz, pick.q
}

// dailyKey namespaces daily answers in quiz_answers so they never collide with
// real quizzes (whose ids never start with "daily:") or with each other.
func dailyKey(t time.Time) string { return "daily:" + t.UTC().Format("2006-01-02") }

// GET /v1/quiz/daily — today's question with the category colour, plus answers.
func (d Deps) handleGetDailyQuiz(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	now := time.Now().UTC()
	cat, quiz, q := dailyPick(now, quizCategoriesFor(langParam(r)))
	key := dailyKey(now)

	answers, err := d.Store.GetQuizAnswers(r.Context(), c.ID, key)
	if err != nil {
		d.serverError(w, "daily: answers", err)
		return
	}
	qv := quizQuestionView{ID: q.ID, Prompt: q.Prompt, Type: string(q.Type), Options: resolveOptions(q.Options)}
	var partner *string
	for i := range answers {
		if answers[i].QuestionID != q.ID {
			continue
		}
		ans := answers[i].Answer
		if answers[i].UserID == userID {
			qv.MyAnswer = &ans
		} else {
			partner = &ans
		}
	}
	if qv.MyAnswer != nil { // reveal partner only after I answer
		qv.PartnerAnswer = partner
	}
	qv.PartnerAnswered = partner != nil
	qv.BothAnswered = qv.MyAnswer != nil && partner != nil

	writeJSON(w, http.StatusOK, dailyQuestionResponse{
		Date: now.Format("2006-01-02"), CategoryID: cat.ID, CategoryTitle: cat.Title,
		ColorKey: cat.ColorKey, Icon: cat.Icon, QuizTitle: quiz.Title, Question: qv,
	})
}

// POST /v1/quiz/daily/answer — answer today's question, notify partner.
func (d Deps) handleAnswerDailyQuiz(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	var req struct {
		Answer string `json:"answer"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	answer := strings.TrimSpace(req.Answer)
	if answer == "" {
		writeError(w, http.StatusBadRequest, "empty", "pick or write an answer first")
		return
	}
	now := time.Now().UTC()
	_, _, q := dailyPick(now, quizCatalog)
	if q.Type == qTypeChoice {
		validOption := false
		for _, o := range q.Options {
			if o.ID == answer {
				validOption = true
				break
			}
		}
		if !validOption {
			writeError(w, http.StatusBadRequest, "unknown_option", "unknown option")
			return
		}
	}
	if err := d.Store.UpsertQuizAnswer(r.Context(), c.ID, dailyKey(now), q.ID, userID, answer); err != nil {
		d.serverError(w, "daily: save", err)
		return
	}
	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{
			Title: "Question of the Day",
			Body:  name + " answered today's question",
			Data:  map[string]string{"type": "daily_quiz"},
		}
	})
	w.WriteHeader(http.StatusNoContent)
}
