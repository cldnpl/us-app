package httpapi

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// resolveOptions maps catalog options to the wire shape, turning photo keywords
// into concrete image URLs (curated in photoURL). Unknown keywords drop the
// image so the app falls back to the icon rather than showing a wrong photo.
func resolveOptions(opts []catalogOption) []quizOptionView {
	out := make([]quizOptionView, 0, len(opts))
	for _, o := range opts {
		v := quizOptionView{Label: o.Label, Icon: o.Icon}
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
	ID             string  `json:"id"`
	Title          string  `json:"title"`
	Icon           string  `json:"icon"`
	ColorKey       string  `json:"colorKey"`
	QuizCount      int     `json:"quizCount"`
	CompletedCount int     `json:"completedCount"` // quizzes I've finished
	Progress       float64 `json:"progress"`       // 0..1, my completion
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
	Label string `json:"label"`
	Icon  string `json:"icon,omitempty"`  // SF Symbol
	Image string `json:"image,omitempty"` // photo keyword
}

type quizQuestionView struct {
	ID            string           `json:"id"`
	Prompt        string           `json:"prompt"`
	Type          string           `json:"type"`
	Options       []quizOptionView `json:"options,omitempty"`
	MyAnswer      *string          `json:"myAnswer"`
	PartnerAnswer *string          `json:"partnerAnswer"` // revealed only after I answer this question
	BothAnswered  bool             `json:"bothAnswered"`
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

	out := make([]quizCategorySummary, 0, len(quizCatalog))
	for _, cat := range quizCatalog {
		done := 0
		for _, q := range cat.Quizzes {
			if quizDone(counts, q.ID, userID, len(q.Questions)) {
				done++
			}
		}
		progress := 0.0
		if len(cat.Quizzes) > 0 {
			progress = float64(done) / float64(len(cat.Quizzes))
		}
		out = append(out, quizCategorySummary{
			ID: cat.ID, Title: cat.Title, Icon: cat.Icon, ColorKey: cat.ColorKey,
			QuizCount: len(cat.Quizzes), CompletedCount: done, Progress: progress,
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
	for _, cc := range quizCatalog {
		if cc.ID == catID {
			cat, found = cc, true
			break
		}
	}
	if !found {
		writeError(w, http.StatusNotFound, "unknown_category", "unknown category")
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
		quizzes = append(quizzes, quizSummary{
			ID: q.ID, Title: q.Title, Icon: q.Icon, Format: string(q.Format), Tag: q.Tag,
			QuestionCount: total,
			MyDone:        quizDone(counts, q.ID, userID, total),
			PartnerDone:   partner.ID != "" && quizDone(counts, q.ID, partner.ID, total),
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
	quiz, found := findQuiz(quizID)
	if !found {
		writeError(w, http.StatusNotFound, "unknown_quiz", "unknown quiz")
		return
	}

	answers, err := d.Store.GetQuizAnswers(r.Context(), c.ID, quizID)
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
	if !quiz.questionIDSet()[req.QuestionID] {
		writeError(w, http.StatusBadRequest, "unknown_question", "unknown question")
		return
	}
	answer := strings.TrimSpace(req.Answer)
	if answer == "" {
		writeError(w, http.StatusBadRequest, "empty", "pick or write an answer first")
		return
	}
	if err := d.Store.UpsertQuizAnswer(r.Context(), c.ID, quizID, req.QuestionID, userID, answer); err != nil {
		d.serverError(w, "quiz: save", err)
		return
	}
	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{
			Title: quiz.Title,
			Body:  name + " answered — see how you compare",
			Data:  map[string]string{"type": "quiz_answer", "quizId": quizID},
		}
	})
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

// dailyPick returns the category, quiz and question for a given day.
func dailyPick(t time.Time) (catalogCategory, catalogQuiz, catalogQuestion) {
	day := int(t.Unix() / 86400) // days since epoch (UTC)
	cat := quizCatalog[((day%len(quizCatalog))+len(quizCatalog))%len(quizCatalog)]
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
	pick := all[(day/len(quizCatalog))%len(all)]
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
	cat, quiz, q := dailyPick(now)
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
	_, _, q := dailyPick(now)
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
