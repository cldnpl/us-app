package httpapi

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// ---- response shapes ----

type quizCategorySummary struct {
	ID             string  `json:"id"`
	Title          string  `json:"title"`
	Emoji          string  `json:"emoji"`
	ColorKey       string  `json:"colorKey"`
	QuizCount      int     `json:"quizCount"`
	CompletedCount int     `json:"completedCount"` // quizzes I've finished
	Progress       float64 `json:"progress"`       // 0..1, my completion
}

type quizSummary struct {
	ID            string `json:"id"`
	Title         string `json:"title"`
	Emoji         string `json:"emoji"`
	Format        string `json:"format"`
	Tag           string `json:"tag,omitempty"`
	QuestionCount int    `json:"questionCount"`
	MyDone        bool   `json:"myDone"`
	PartnerDone   bool   `json:"partnerDone"`
}

type quizCategoryDetail struct {
	ID       string        `json:"id"`
	Title    string        `json:"title"`
	Emoji    string        `json:"emoji"`
	ColorKey string        `json:"colorKey"`
	Quizzes  []quizSummary `json:"quizzes"`
}

type quizQuestionView struct {
	ID            string   `json:"id"`
	Prompt        string   `json:"prompt"`
	Type          string   `json:"type"`
	Options       []string `json:"options,omitempty"`
	MyAnswer      *string  `json:"myAnswer"`
	PartnerAnswer *string  `json:"partnerAnswer"` // revealed only after I answer this question
	BothAnswered  bool     `json:"bothAnswered"`
}

type quizDetail struct {
	ID        string             `json:"id"`
	Title     string             `json:"title"`
	Emoji     string             `json:"emoji"`
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
			ID: cat.ID, Title: cat.Title, Emoji: cat.Emoji, ColorKey: cat.ColorKey,
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
			ID: q.ID, Title: q.Title, Emoji: q.Emoji, Format: string(q.Format), Tag: q.Tag,
			QuestionCount: total,
			MyDone:        quizDone(counts, q.ID, userID, total),
			PartnerDone:   partner.ID != "" && quizDone(counts, q.ID, partner.ID, total),
		})
	}
	writeJSON(w, http.StatusOK, quizCategoryDetail{
		ID: cat.ID, Title: cat.Title, Emoji: cat.Emoji, ColorKey: cat.ColorKey, Quizzes: quizzes,
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
		v := quizQuestionView{ID: q.ID, Prompt: q.Prompt, Type: string(q.Type), Options: q.Options}
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
		ID: quiz.ID, Title: quiz.Title, Emoji: quiz.Emoji, Format: string(quiz.Format), Tag: quiz.Tag, Questions: views,
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
			Title: quiz.Emoji + " " + quiz.Title,
			Body:  name + " answered — see how you compare",
			Data:  map[string]string{"type": "quiz_answer", "quizId": quizID},
		}
	})
	w.WriteHeader(http.StatusNoContent)
}
