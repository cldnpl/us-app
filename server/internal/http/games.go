package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// ---- Tic-Tac-Toe ----

type tttState struct {
	Board  [9]string `json:"board"` // "X", "O", or ""
	X      string    `json:"x"`     // user id playing X
	O      string    `json:"o"`     // user id playing O
	Winner string    `json:"winner"`
}

type gameResponse struct {
	ID         string          `json:"id"`
	GameType   string          `json:"gameType"`
	State      json.RawMessage `json:"state"`
	TurnUserID *string         `json:"turnUserId"`
	Status     string          `json:"status"`
	UpdatedAt  time.Time       `json:"updatedAt"`
}

func toGameResponse(g store.GameSession) gameResponse {
	return gameResponse{
		ID: g.ID, GameType: g.GameType, State: json.RawMessage(g.State),
		TurnUserID: g.TurnUserID, Status: g.Status, UpdatedAt: g.UpdatedAt,
	}
}

func tttWinner(b [9]string) string {
	lines := [8][3]int{{0, 1, 2}, {3, 4, 5}, {6, 7, 8}, {0, 3, 6}, {1, 4, 7}, {2, 5, 8}, {0, 4, 8}, {2, 4, 6}}
	for _, l := range lines {
		if b[l[0]] != "" && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]] {
			return b[l[0]]
		}
	}
	for _, c := range b {
		if c == "" {
			return "" // still in progress
		}
	}
	return "draw"
}

func (d Deps) newTicTacToe(ctx context.Context, coupleID, creatorID, partnerID string) (store.GameSession, error) {
	raw, _ := json.Marshal(tttState{X: creatorID, O: partnerID})
	return d.Store.CreateGame(ctx, coupleID, "tictactoe", raw, creatorID)
}

// gameCouple resolves the caller's couple, writing the appropriate error.
func (d Deps) gameCouple(w http.ResponseWriter, r *http.Request, userID string) (store.Couple, bool) {
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return store.Couple{}, false
	} else if err != nil {
		d.serverError(w, "games: couple", err)
		return store.Couple{}, false
	}
	return c, true
}

func (d Deps) handleGetGame(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if chi.URLParam(r, "type") != "tictactoe" {
		writeError(w, http.StatusNotFound, "unknown_game", "unknown game")
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}

	g, err := d.Store.GetLatestGame(r.Context(), c.ID, "tictactoe")
	if errors.Is(err, store.ErrNotFound) {
		partner, perr := d.Store.GetPartner(r.Context(), c.ID, userID)
		if perr != nil {
			writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
			return
		}
		g, err = d.newTicTacToe(r.Context(), c.ID, userID, partner.ID)
	}
	if err != nil {
		d.serverError(w, "games: get", err)
		return
	}
	writeJSON(w, http.StatusOK, toGameResponse(g))
}

type moveRequest struct {
	Index int `json:"index"`
}

func (d Deps) handleGameMove(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if chi.URLParam(r, "type") != "tictactoe" {
		writeError(w, http.StatusNotFound, "unknown_game", "unknown game")
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	var req moveRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	g, err := d.Store.GetLatestGame(r.Context(), c.ID, "tictactoe")
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "no_game", "no active game")
		return
	} else if err != nil {
		d.serverError(w, "games: get", err)
		return
	}
	if g.Status != "active" {
		writeError(w, http.StatusConflict, "game_over", "this game is finished")
		return
	}
	if g.TurnUserID == nil || *g.TurnUserID != userID {
		writeError(w, http.StatusForbidden, "not_your_turn", "it's not your turn")
		return
	}

	var st tttState
	if err := json.Unmarshal(g.State, &st); err != nil {
		d.serverError(w, "games: state", err)
		return
	}
	if req.Index < 0 || req.Index > 8 || st.Board[req.Index] != "" {
		writeError(w, http.StatusBadRequest, "invalid_move", "that square is taken")
		return
	}

	mark := "O"
	if userID == st.X {
		mark = "X"
	}
	st.Board[req.Index] = mark

	status := "active"
	var nextTurn *string
	if winner := tttWinner(st.Board); winner != "" {
		st.Winner = winner
		status = "finished"
	} else {
		next := st.O
		if userID == st.O {
			next = st.X
		}
		nextTurn = &next
	}

	raw, _ := json.Marshal(st)
	g2, err := d.Store.UpdateGame(r.Context(), g.ID, raw, nextTurn, status)
	if err != nil {
		d.serverError(w, "games: update", err)
		return
	}
	if status == "active" {
		d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
			return push.Notification{Title: "🎮", Body: name + " made a move — your turn", Data: map[string]string{"type": "game_move"}}
		})
	}
	writeJSON(w, http.StatusOK, toGameResponse(g2))
}

func (d Deps) handleNewGame(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	if chi.URLParam(r, "type") != "tictactoe" {
		writeError(w, http.StatusNotFound, "unknown_game", "unknown game")
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	partner, err := d.Store.GetPartner(r.Context(), c.ID, userID)
	if err != nil {
		writeError(w, http.StatusConflict, "not_paired", "pair with your partner first")
		return
	}
	_ = d.Store.FinishActiveGames(r.Context(), c.ID, "tictactoe")
	g, err := d.newTicTacToe(r.Context(), c.ID, userID, partner.ID)
	if err != nil {
		d.serverError(w, "games: create", err)
		return
	}
	writeJSON(w, http.StatusCreated, toGameResponse(g))
}

// ---- Daily question ----

var dailyQuestions = []string{
	"What's your favorite memory of us?",
	"Where in the world should we travel next?",
	"What's one little thing I do that makes you smile?",
	"If we had a whole free day tomorrow, how would we spend it?",
	"What song always reminds you of us?",
	"What's something new you'd like us to try together?",
	"What made you fall for me?",
	"What's your favorite way to spend a lazy morning together?",
	"What's a small goal we could chase together this month?",
	"What meal should we cook together next?",
	"What do you look forward to most about seeing me?",
	"What's a tiny thing I could do this week to make your day?",
}

func questionForDay(t time.Time) string {
	return dailyQuestions[t.YearDay()%len(dailyQuestions)]
}

type questionResponse struct {
	Question      string  `json:"question"`
	MyAnswer      *string `json:"myAnswer"`
	PartnerAnswer *string `json:"partnerAnswer"`
	BothAnswered  bool    `json:"bothAnswered"`
}

func (d Deps) handleGetQuestion(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	now := time.Now()
	answers, err := d.Store.GetAnswers(r.Context(), c.ID, now)
	if err != nil {
		d.serverError(w, "question: answers", err)
		return
	}

	resp := questionResponse{Question: questionForDay(now)}
	var partner *string
	for i := range answers {
		ans := answers[i].Answer
		if answers[i].UserID == userID {
			resp.MyAnswer = &ans
		} else {
			partner = &ans
		}
	}
	resp.BothAnswered = len(answers) == 2
	if resp.MyAnswer != nil { // reveal the partner's answer only after you answer
		resp.PartnerAnswer = partner
	}
	writeJSON(w, http.StatusOK, resp)
}

type answerRequest struct {
	Answer string `json:"answer"`
}

func (d Deps) handleAnswerQuestion(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	var req answerRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	answer := strings.TrimSpace(req.Answer)
	if answer == "" {
		writeError(w, http.StatusBadRequest, "empty", "write an answer first")
		return
	}
	if err := d.Store.UpsertAnswer(r.Context(), c.ID, time.Now(), userID, answer); err != nil {
		d.serverError(w, "question: save", err)
		return
	}
	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{Title: "💭", Body: name + " answered today's question", Data: map[string]string{"type": "daily_question"}}
	})
	w.WriteHeader(http.StatusNoContent)
}
