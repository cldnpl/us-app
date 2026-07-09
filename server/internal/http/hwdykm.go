package httpapi

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/push"
)

// "How Well Do You Know Me": per question one partner is the subject (answers
// honestly) and the other guesses. Subject alternates by question index using a
// stable ordering of the two user ids, so both devices agree on roles. Answers
// reuse quiz_answers under quiz_id "hwdykm:<packID>".

func hwdykmKey(packID string) string { return "hwdykm:" + packID }

type hwdykmPackSummary struct {
	ID            string `json:"id"`
	Title         string `json:"title"`
	Icon          string `json:"icon"`
	ColorKey      string `json:"colorKey"`
	Tag           string `json:"tag"`
	QuestionCount int    `json:"questionCount"`
	MyDone        bool   `json:"myDone"`
	BothDone      bool   `json:"bothDone"`
}

type hwdykmQuestionView struct {
	ID           string   `json:"id"`
	Prompt       string   `json:"prompt"`
	Options      []string `json:"options"`
	SubjectIsMe  bool     `json:"subjectIsMe"` // true → I answer honestly; false → I guess my partner
	MyAnswer     *string  `json:"myAnswer"`
	HonestAnswer *string  `json:"honestAnswer"` // reveal only
	Guess        *string  `json:"guess"`        // reveal only
	Matched      bool     `json:"matched"`
}

type hwdykmPackDetail struct {
	ID        string               `json:"id"`
	Title     string               `json:"title"`
	Icon      string               `json:"icon"`
	ColorKey  string               `json:"colorKey"`
	Tag       string               `json:"tag"`
	MyDone    bool                 `json:"myDone"`
	BothDone  bool                 `json:"bothDone"`
	Score     int                  `json:"score"` // 0..100, valid when bothDone
	Questions []hwdykmQuestionView `json:"questions"`
}

// orderedIDs returns the two user ids in a stable order (subject A, subject B).
func orderedIDs(a, b string) (string, string) {
	if b < a {
		return b, a
	}
	return a, b
}

// GET /v1/games/hwdykm/packs
func (d Deps) handleListHwdykmPacks(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)

	keys, err := d.Store.GetQuizAnswerKeys(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "hwdykm: keys", err)
		return
	}
	// quizID -> userID -> count of answered questions
	counts := make(map[string]map[string]int)
	for _, k := range keys {
		if counts[k.QuizID] == nil {
			counts[k.QuizID] = make(map[string]int)
		}
		counts[k.QuizID][k.UserID]++
	}

	out := make([]hwdykmPackSummary, 0, len(hwdykmPacks))
	for _, p := range hwdykmPacks {
		total := len(p.Questions)
		key := hwdykmKey(p.ID)
		myDone := counts[key][userID] >= total && total > 0
		partnerDone := partner.ID != "" && counts[key][partner.ID] >= total && total > 0
		out = append(out, hwdykmPackSummary{
			ID: p.ID, Title: p.Title, Icon: p.Icon, ColorKey: p.ColorKey, Tag: p.Tag,
			QuestionCount: total, MyDone: myDone, BothDone: myDone && partnerDone,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"packs": out})
}

// GET /v1/games/hwdykm/packs/{id}
func (d Deps) handleGetHwdykmPack(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	pack, found := findHwdykmPack(chi.URLParam(r, "id"))
	if !found {
		writeError(w, http.StatusNotFound, "unknown_pack", "unknown pack")
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	aID, bID := orderedIDs(userID, partner.ID)

	answers, err := d.Store.GetQuizAnswers(r.Context(), c.ID, hwdykmKey(pack.ID))
	if err != nil {
		d.serverError(w, "hwdykm: answers", err)
		return
	}
	// userID -> questionID -> answer
	byUser := make(map[string]map[string]string)
	for _, a := range answers {
		if byUser[a.UserID] == nil {
			byUser[a.UserID] = make(map[string]string)
		}
		byUser[a.UserID][a.QuestionID] = a.Answer
	}

	myDone, partnerDone := true, true
	for _, q := range pack.Questions {
		if byUser[userID][q.ID] == "" {
			myDone = false
		}
		if partner.ID == "" || byUser[partner.ID][q.ID] == "" {
			partnerDone = false
		}
	}
	bothDone := myDone && partnerDone

	views := make([]hwdykmQuestionView, 0, len(pack.Questions))
	matches := 0
	for i, q := range pack.Questions {
		subject := aID
		if i%2 == 1 {
			subject = bID
		}
		guesser := aID
		if subject == aID {
			guesser = bID
		}
		v := hwdykmQuestionView{ID: q.ID, Prompt: q.Prompt, Options: q.Options, SubjectIsMe: subject == userID}
		if mine, ok := byUser[userID][q.ID]; ok && mine != "" {
			v.MyAnswer = &mine
		}
		if bothDone {
			honest := byUser[subject][q.ID]
			guess := byUser[guesser][q.ID]
			v.HonestAnswer = &honest
			v.Guess = &guess
			v.Matched = honest != "" && honest == guess
			if v.Matched {
				matches++
			}
		}
		views = append(views, v)
	}
	score := 0
	if bothDone && len(pack.Questions) > 0 {
		score = matches * 100 / len(pack.Questions)
	}

	writeJSON(w, http.StatusOK, hwdykmPackDetail{
		ID: pack.ID, Title: pack.Title, Icon: pack.Icon, ColorKey: pack.ColorKey, Tag: pack.Tag,
		MyDone: myDone, BothDone: bothDone, Score: score, Questions: views,
	})
}

// POST /v1/games/hwdykm/packs/{id}/answer  { questionId, answer }
func (d Deps) handleAnswerHwdykmPack(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	pack, found := findHwdykmPack(chi.URLParam(r, "id"))
	if !found {
		writeError(w, http.StatusNotFound, "unknown_pack", "unknown pack")
		return
	}
	var req struct {
		QuestionID string `json:"questionId"`
		Answer     string `json:"answer"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	valid := false
	for _, q := range pack.Questions {
		if q.ID == req.QuestionID {
			valid = true
			break
		}
	}
	if !valid {
		writeError(w, http.StatusBadRequest, "unknown_question", "unknown question")
		return
	}
	answer := strings.TrimSpace(req.Answer)
	if answer == "" {
		writeError(w, http.StatusBadRequest, "empty", "pick an answer first")
		return
	}
	if err := d.Store.UpsertQuizAnswer(r.Context(), c.ID, hwdykmKey(pack.ID), req.QuestionID, userID, answer); err != nil {
		d.serverError(w, "hwdykm: save", err)
		return
	}
	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{
			Title: "How Well Do You Know Me",
			Body:  name + " is playing " + pack.Title + " — join in!",
			Data:  map[string]string{"type": "hwdykm", "packId": pack.ID},
		}
	})
	w.WriteHeader(http.StatusNoContent)
}
