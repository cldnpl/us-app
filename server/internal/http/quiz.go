package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// ---- catalog generation (per couple) ----------------------------------------
//
// Once a couple has completed every quiz in every category, the whole quiz
// catalog rotates: a monotonic "generation" is bumped on their game_sessions
// `quiz_catalog` row, and every quiz answer key gets prefixed with `qg<gen>:`
// from that point on. Previous answers stay in the DB but no longer surface,
// so the app shows the same catalog structure at 0% completion again. The
// underlying questions are unchanged for now — the LLM per-quiz regeneration
// hooks off the same generation number in a follow-up.

const quizCatalogGameType = "quiz_catalog"

type quizCatalogState struct {
	Generation int `json:"gen"`
}

// quizCatalogGen returns the couple's current catalog generation (>=1), the
// game_sessions id that stores it (empty if no row exists yet), and whether a
// row already exists at all.
func (d Deps) quizCatalogGen(ctx context.Context, coupleID string) (int, string, error) {
	g, err := d.Store.GetLatestGame(ctx, coupleID, quizCatalogGameType)
	if err != nil {
		if err == store.ErrNotFound {
			return 1, "", nil
		}
		return 1, "", err
	}
	var st quizCatalogState
	if len(g.State) > 0 {
		_ = json.Unmarshal(g.State, &st)
	}
	if st.Generation < 1 {
		st.Generation = 1
	}
	return st.Generation, g.ID, nil
}

// bumpQuizCatalogGen persists gen+1 and returns the new value. Caller is
// expected to have just verified that everything is bothDone under `gen`.
func (d Deps) bumpQuizCatalogGen(ctx context.Context, coupleID, sessionID string, gen int) (int, error) {
	next := gen + 1
	raw, _ := json.Marshal(quizCatalogState{Generation: next})
	if sessionID == "" {
		if _, err := d.Store.CreateGame(ctx, coupleID, quizCatalogGameType, raw, ""); err != nil {
			return gen, err
		}
		return next, nil
	}
	if _, err := d.Store.UpdateGame(ctx, sessionID, raw, nil, "active"); err != nil {
		return gen, err
	}
	return next, nil
}

// quizAnswerKey composes the DB key for a quiz's answers under the current
// catalog generation. Gen 1 is unprefixed for backwards compatibility with
// answers stored before catalog rotation existed — those pre-rotation rows
// still resolve as gen 1 without a migration.
func quizAnswerKey(quizID string, gen int) string {
	if gen <= 1 {
		return quizID
	}
	return fmt.Sprintf("qg%d:%s", gen, quizID)
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
	gen, sessionID, err := d.quizCatalogGen(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "quiz: gen", err)
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

	// Whole-catalog rotation: once both partners have completed every quiz in
	// every category under the current generation, bump the generation so the
	// answer keys stop matching and every category is fresh again.
	if partner.ID != "" {
		allDone := true
		for _, cat := range categories {
			for _, q := range cat.Quizzes {
				key := quizAnswerKey(q.ID, gen)
				if !quizDone(counts, key, userID, len(q.Questions)) ||
					!quizDone(counts, key, partner.ID, len(q.Questions)) {
					allDone = false
					break
				}
			}
			if !allDone {
				break
			}
		}
		if allDone {
			if next, berr := d.bumpQuizCatalogGen(r.Context(), c.ID, sessionID, gen); berr == nil {
				gen = next
			} else {
				d.Logger.Warn("quiz: bump catalog", "err", berr)
			}
		}
	}

	out := make([]quizCategorySummary, 0, len(categories))
	for _, cat := range categories {
		done, partnerDone, yourTurn := 0, 0, 0
		for _, q := range cat.Quizzes {
			key := quizAnswerKey(q.ID, gen)
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

	gen, _, err := d.quizCatalogGen(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "quiz: gen", err)
		return
	}
	keys, err := d.Store.GetQuizAnswerKeys(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "quiz: keys", err)
		return
	}
	counts := completionByUser(keys)
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)

	quizzes := make([]quizSummary, 0, len(cat.Quizzes))
	for _, q := range cat.Quizzes {
		total := len(q.Questions)
		key := quizAnswerKey(q.ID, gen)
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
	quiz, found := findQuizIn(quizCategoriesFor(langParam(r)), quizID)
	if !found {
		writeError(w, http.StatusNotFound, "unknown_quiz", "unknown quiz")
		return
	}
	gen, _, gerr := d.quizCatalogGen(r.Context(), c.ID)
	if gerr != nil {
		d.serverError(w, "quiz: gen", gerr)
		return
	}
	key := quizAnswerKey(quizID, gen)

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

	views := make([]quizQuestionView, 0, len(quiz.Questions))
	for _, q := range quiz.Questions {
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
	quiz, found := findQuiz(quizID)
	if !found {
		writeError(w, http.StatusNotFound, "unknown_quiz", "unknown quiz")
		return
	}
	var req quizAnswerRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	question, found := quiz.question(req.QuestionID)
	if !found {
		writeError(w, http.StatusBadRequest, "unknown_question", "unknown question")
		return
	}
	answer := strings.TrimSpace(req.Answer)
	if answer == "" {
		writeError(w, http.StatusBadRequest, "empty", "pick or write an answer first")
		return
	}
	// Choice questions store the option id, never its (localizable) label —
	// otherwise two partners on different languages could never match, and a
	// stored answer would stop resolving the moment the label wording changes.
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
	gen, _, gerr := d.quizCatalogGen(r.Context(), c.ID)
	if gerr != nil {
		d.serverError(w, "quiz: gen", gerr)
		return
	}
	key := quizAnswerKey(quizID, gen)
	if err := d.Store.UpsertQuizAnswer(r.Context(), c.ID, key, req.QuestionID, userID, answer); err != nil {
		d.serverError(w, "quiz: save", err)
		return
	}
	d.notifyTurnOrResults(r.Context(), c.ID, userID, key, quiz.Title, len(quiz.Questions),
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
