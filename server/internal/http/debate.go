package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/judge"
	"github.com/sharepact/us/internal/push"
)

// Couples Debate: per motion (round) one partner is assigned FOR and the other
// AGAINST, alternating by round index so both argue each side across a pack.
// Each writes their case privately; once both have argued a round, an AI judge
// scores it and crowns a round winner. Arguments reuse quiz_answers under
// quiz_id "debate:<packID>"; judge verdicts are cached in game_sessions (keyed
// by game_type "debate:<packID>") so both partners see the same result.

const maxArgumentLen = 1000

func debateKey(packID string) string  { return "debate:" + packID }
func debateGame(packID string) string { return "debate:" + packID }

type debatePackSummary struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	Icon       string `json:"icon"`
	ColorKey   string `json:"colorKey"`
	Tag        string `json:"tag"`
	RoundCount int    `json:"roundCount"`
	MyDone     bool   `json:"myDone"`
	BothDone   bool   `json:"bothDone"`
}

type debateRoundView struct {
	ID              string  `json:"id"`
	Motion          string  `json:"motion"`
	MySide          string  `json:"mySide"` // "for" | "against"
	MyArgument      *string `json:"myArgument"`
	PartnerArgument *string `json:"partnerArgument"` // revealed once both have argued
	Judged          bool    `json:"judged"`
	MyScore         *int    `json:"myScore"`
	PartnerScore    *int    `json:"partnerScore"`
	RoundWinner     *string `json:"roundWinner"` // "me" | "partner" | "tie"
	Verdict         *string `json:"verdict"`
}

type debatePackDetail struct {
	ID            string            `json:"id"`
	Title         string            `json:"title"`
	Icon          string            `json:"icon"`
	ColorKey      string            `json:"colorKey"`
	Tag           string            `json:"tag"`
	MyDone        bool              `json:"myDone"`
	BothDone      bool              `json:"bothDone"`
	OverallWinner *string           `json:"overallWinner"` // "me" | "partner" | "tie", when bothDone
	MyWins        int               `json:"myWins"`
	PartnerWins   int               `json:"partnerWins"`
	Rounds        []debateRoundView `json:"rounds"`
}

// forUserForRound returns the user id arguing FOR the motion in round i, given
// the couple's two ids in stable order. Sides alternate each round.
func forUserForRound(i int, aID, bID string) (forUser, againstUser string) {
	if i%2 == 0 {
		return aID, bID
	}
	return bID, aID
}

// GET /v1/games/debate/packs
func (d Deps) handleListDebatePacks(w http.ResponseWriter, r *http.Request) {
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
		d.serverError(w, "debate: keys", err)
		return
	}
	counts := make(map[string]map[string]int)
	for _, k := range keys {
		if counts[k.QuizID] == nil {
			counts[k.QuizID] = make(map[string]int)
		}
		counts[k.QuizID][k.UserID]++
	}

	out := make([]debatePackSummary, 0, len(debatePacks))
	for _, p := range debatePacks {
		total := len(p.Motions)
		key := debateKey(p.ID)
		myDone := total > 0 && counts[key][userID] >= total
		partnerDone := partner.ID != "" && total > 0 && counts[key][partner.ID] >= total
		out = append(out, debatePackSummary{
			ID: p.ID, Title: p.Title, Icon: p.Icon, ColorKey: p.ColorKey, Tag: p.Tag,
			RoundCount: total, MyDone: myDone, BothDone: myDone && partnerDone,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"packs": out})
}

// GET /v1/games/debate/packs/{id}
func (d Deps) handleGetDebatePack(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	pack, found := findDebatePack(chi.URLParam(r, "id"))
	if !found {
		writeError(w, http.StatusNotFound, "unknown_pack", "unknown pack")
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	aID, bID := orderedIDs(userID, partner.ID)

	answers, err := d.Store.GetQuizAnswers(r.Context(), c.ID, debateKey(pack.ID))
	if err != nil {
		d.serverError(w, "debate: answers", err)
		return
	}
	byUser := make(map[string]map[string]string)
	for _, a := range answers {
		if byUser[a.UserID] == nil {
			byUser[a.UserID] = make(map[string]string)
		}
		byUser[a.UserID][a.QuestionID] = a.Answer
	}

	// Load any cached verdicts, then judge rounds that are newly complete.
	verdicts := make(map[string]judge.Verdict)
	cacheID := ""
	if g, gerr := d.Store.GetLatestGame(r.Context(), c.ID, debateGame(pack.ID)); gerr == nil {
		cacheID = g.ID
		_ = json.Unmarshal(g.State, &verdicts)
	}
	dirty := false
	j := judge.New(d.Config.AnthropicAPIKey, d.Config.AnthropicModel)
	for i, m := range pack.Motions {
		forUser, againstUser := forUserForRound(i, aID, bID)
		forArg := byUser[forUser][m.ID]
		againstArg := byUser[againstUser][m.ID]
		if forArg == "" || againstArg == "" {
			continue
		}
		if _, done := verdicts[m.ID]; done {
			continue
		}
		verdicts[m.ID] = j.Score(r.Context(), m.Prompt, forArg, againstArg)
		dirty = true
	}
	if dirty {
		raw, _ := json.Marshal(verdicts)
		if cacheID == "" {
			if _, cerr := d.Store.CreateGame(r.Context(), c.ID, debateGame(pack.ID), raw, userID); cerr != nil {
				d.Logger.Warn("debate: cache verdicts", "err", cerr)
			}
		} else if _, uerr := d.Store.UpdateGame(r.Context(), cacheID, raw, nil, "active"); uerr != nil {
			d.Logger.Warn("debate: update verdicts", "err", uerr)
		}
	}

	rounds := make([]debateRoundView, 0, len(pack.Motions))
	myWins, partnerWins := 0, 0
	myDone, bothDone := true, true
	for i, m := range pack.Motions {
		forUser, againstUser := forUserForRound(i, aID, bID)
		mySide := "against"
		if forUser == userID {
			mySide = "for"
		}
		v := debateRoundView{ID: m.ID, Motion: m.Prompt, MySide: mySide}

		if mine := byUser[userID][m.ID]; mine != "" {
			v.MyArgument = &mine
		} else {
			myDone = false
		}

		bothArgued := byUser[forUser][m.ID] != "" && byUser[againstUser][m.ID] != ""
		if !bothArgued {
			bothDone = false
		}
		if v.MyArgument != nil && bothArgued {
			pa := byUser[partner.ID][m.ID]
			v.PartnerArgument = &pa
		}

		if vr, done := verdicts[m.ID]; done {
			v.Judged = true
			myScore, partnerScore := vr.AgainstScore, vr.ForScore
			if mySide == "for" {
				myScore, partnerScore = vr.ForScore, vr.AgainstScore
			}
			v.MyScore = &myScore
			v.PartnerScore = &partnerScore
			var rw string
			switch {
			case vr.Winner == "tie":
				rw = "tie"
			case vr.Winner == mySide:
				rw = "me"
				myWins++
			default:
				rw = "partner"
				partnerWins++
			}
			v.RoundWinner = &rw
			reason := vr.Reason
			v.Verdict = &reason
		}
		rounds = append(rounds, v)
	}

	detail := debatePackDetail{
		ID: pack.ID, Title: pack.Title, Icon: pack.Icon, ColorKey: pack.ColorKey, Tag: pack.Tag,
		MyDone: myDone, BothDone: bothDone, MyWins: myWins, PartnerWins: partnerWins, Rounds: rounds,
	}
	if bothDone {
		overall := "tie"
		if myWins > partnerWins {
			overall = "me"
		} else if partnerWins > myWins {
			overall = "partner"
		}
		detail.OverallWinner = &overall
	}
	writeJSON(w, http.StatusOK, detail)
}

// POST /v1/games/debate/packs/{id}/argue  { roundId, argument }
func (d Deps) handleArgueDebate(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	pack, found := findDebatePack(chi.URLParam(r, "id"))
	if !found {
		writeError(w, http.StatusNotFound, "unknown_pack", "unknown pack")
		return
	}
	var req struct {
		RoundID  string `json:"roundId"`
		Argument string `json:"argument"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	valid := false
	for _, m := range pack.Motions {
		if m.ID == req.RoundID {
			valid = true
			break
		}
	}
	if !valid {
		writeError(w, http.StatusBadRequest, "unknown_round", "unknown round")
		return
	}
	argument := strings.TrimSpace(req.Argument)
	if argument == "" {
		writeError(w, http.StatusBadRequest, "empty", "make your case first")
		return
	}
	if len(argument) > maxArgumentLen {
		argument = argument[:maxArgumentLen]
	}
	if err := d.Store.UpsertQuizAnswer(r.Context(), c.ID, debateKey(pack.ID), req.RoundID, userID, argument); err != nil {
		d.serverError(w, "debate: save", err)
		return
	}
	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{
			Title: "Couples Debate",
			Body:  name + " made their case in " + pack.Title + " — argue back!",
			Data:  map[string]string{"type": "debate", "packId": pack.ID},
		}
	})
	w.WriteHeader(http.StatusNoContent)
}
