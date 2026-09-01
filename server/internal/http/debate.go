package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/generator"
	"github.com/sharepact/us/internal/judge"
)

// Couples Debate: both partners get the SAME prompt in every round and each
// makes their own case for it privately — no assigned sides. Once both have
// argued a round, an AI judge compares the two answers to that one prompt and
// crowns a round winner; judging answers to opposite prompts would compare
// nothing.
//
// Each pack has a per-couple "round" (see packRoundStore): a generation number
// + the current set of motions + judge verdicts + a seenBy list. Arguments live
// in quiz_answers with the composite quiz_id `debate:<packID>:g<gen>` so old
// generations linger in the DB (searchable, but ignored by the current view).
// When both partners have opened the results and both have answered every
// motion, the round is retired: gen++, a fresh batch of motions is generated
// by Claude (with the pack's seed catalog as fallback), and the pack becomes
// playable again with brand-new prompts.

const maxArgumentLen = 1000

// debateKey / debateGame legacy prefixes are gone: everything now lives under
// the composite quiz_id `debate:<packID>:g<gen>` (answers) and the game_type
// `debate_pack:<packID>` (round state). Answers written under the old
// generation-less keys remain in the DB but do not surface anywhere.
func debateAnswerKey(packID string, gen int) string {
	return fmt.Sprintf("debate:%s:g%d", packID, gen)
}
func debateRoundGameType(packID string) string { return "debate_pack:" + packID }

// debateRoundContent is what we persist per generation: the actual motions the
// couple is arguing this round. We serialize it into packRoundState.Content so
// the round helper can stay content-agnostic.
type debateRoundContent struct {
	Motions []debateMotion `json:"motions"`
}

// debateRoundVerdicts maps motion id -> judge Verdict, cached on the round so
// both partners see identical results.
type debateRoundVerdicts map[string]judge.Verdict

type debatePackSummary struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Icon        string `json:"icon"`
	ColorKey    string `json:"colorKey"`
	Tag         string `json:"tag"`
	RoundCount  int    `json:"roundCount"`
	MyDone      bool   `json:"myDone"`
	PartnerDone bool   `json:"partnerDone"`
	BothDone    bool   `json:"bothDone"`
}

type debateRoundView struct {
	ID     string `json:"id"`
	Motion string `json:"motion"` // the one prompt both partners answer
	// Deprecated; kept only so a build shipped before sides were removed still
	// decodes this response. Always "for" now: there are no sides to assign.
	MySide          string  `json:"mySide"`
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

// ---- helpers -----------------------------------------------------------------

// debateRoundMotions returns the motions for the couple's current round of a
// pack, creating (or bumping) the round as needed. `seed` is the pack's
// hard-coded starter motions from the catalog — used as the fallback content
// for the very first round and as the "avoid" hint on later regenerations so
// Claude doesn't hand back the same lines.
func (d Deps) debateRoundMotions(ctx context.Context, coupleID string, seed debatePack, lang string) (int, []debateMotion, packRoundState, *packRoundStore, error) {
	rs := d.packRound(coupleID, debateRoundGameType(seed.ID))
	if err := rs.load(ctx); err != nil {
		return 0, nil, packRoundState{}, nil, err
	}
	st := rs.current()
	if st.Generation == 0 {
		// First round: seed straight from the catalog rather than paying for an
		// LLM call the couple has never played a round.
		content := debateRoundContent{Motions: seed.Motions}
		raw, _ := json.Marshal(content)
		newSt, err := rs.initialize(ctx, "", raw)
		if err != nil {
			return 0, nil, packRoundState{}, nil, err
		}
		return newSt.Generation, seed.Motions, newSt, rs, nil
	}
	var content debateRoundContent
	_ = json.Unmarshal(st.Content, &content)
	if len(content.Motions) < len(seed.Motions) {
		// Corrupted / partial state — repair by falling back to the seed set for
		// this generation rather than exposing a broken shorter round.
		content.Motions = seed.Motions
	}
	return st.Generation, content.Motions, st, rs, nil
}

// generateFreshDebateMotions asks Claude for a new batch of motions in the
// pack's theme, using the seed catalog as both the "avoid" hint and the
// fallback content when Claude is unreachable. Motion IDs are re-seeded per
// generation so answers under different rounds never collide.
func (d Deps) generateFreshDebateMotions(ctx context.Context, seed debatePack, lang string, nextGen int) []debateMotion {
	gen := generator.New(d.Config.AnthropicAPIKey, d.Config.AnthropicModel)
	avoid := make([]string, 0, len(seed.Motions))
	fallback := make([]string, 0, len(seed.Motions))
	for _, m := range seed.Motions {
		avoid = append(avoid, m.Prompt)
		fallback = append(fallback, m.Prompt)
	}
	description := ""
	if seed.Tag != "" {
		description = "Tone: " + seed.Tag + "."
	}
	prompts := gen.DebatePrompts(ctx, seed.Title, description, len(seed.Motions), avoid, lang, fallback)
	out := make([]debateMotion, 0, len(prompts))
	for i, p := range prompts {
		out = append(out, debateMotion{
			ID:     fmt.Sprintf("%s_g%d_r%d", seed.ID, nextGen, i+1),
			Prompt: p,
		})
	}
	return out
}

// ---- handlers ---------------------------------------------------------------

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
	// quizID -> userID -> count of answered questions
	counts := make(map[string]map[string]int)
	for _, k := range keys {
		if counts[k.QuizID] == nil {
			counts[k.QuizID] = make(map[string]int)
		}
		counts[k.QuizID][k.UserID]++
	}

	packs := debatePacksFor(langParam(r))
	out := make([]debatePackSummary, 0, len(packs))
	for _, p := range packs {
		gen, motions, _, _, rerr := d.debateRoundMotions(r.Context(), c.ID, p, langParam(r))
		if rerr != nil {
			d.serverError(w, "debate: round", rerr)
			return
		}
		total := len(motions)
		key := debateAnswerKey(p.ID, gen)
		myDone := total > 0 && counts[key][userID] >= total
		partnerDone := partner.ID != "" && total > 0 && counts[key][partner.ID] >= total
		out = append(out, debatePackSummary{
			ID: p.ID, Title: p.Title, Icon: p.Icon, ColorKey: p.ColorKey, Tag: p.Tag,
			RoundCount: total, MyDone: myDone, PartnerDone: partnerDone,
			BothDone: myDone && partnerDone,
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
	pack, found := findDebatePackIn(debatePacksFor(langParam(r)), chi.URLParam(r, "id"))
	if !found {
		writeError(w, http.StatusNotFound, "unknown_pack", "unknown pack")
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	aID, bID := orderedIDs(userID, partner.ID)

	gen, motions, st, rs, err := d.debateRoundMotions(r.Context(), c.ID, pack, langParam(r))
	if err != nil {
		d.serverError(w, "debate: round", err)
		return
	}
	quizID := debateAnswerKey(pack.ID, gen)

	answers, err := d.Store.GetQuizAnswers(r.Context(), c.ID, quizID)
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

	// Load cached verdicts (per this round) and judge any newly complete motions.
	verdicts := make(debateRoundVerdicts)
	if len(st.Verdicts) > 0 {
		_ = json.Unmarshal(st.Verdicts, &verdicts)
	}
	dirty := false
	j := judge.New(d.Config.AnthropicAPIKey, d.Config.AnthropicModel)
	for _, m := range motions {
		argA := byUser[aID][m.ID]
		argB := byUser[bID][m.ID]
		if argA == "" || argB == "" {
			continue
		}
		if _, done := verdicts[m.ID]; done {
			continue
		}
		verdicts[m.ID] = j.Score(r.Context(), m.Prompt, argA, argB, langParam(r))
		dirty = true
	}
	if dirty {
		raw, _ := json.Marshal(verdicts)
		st.Verdicts = raw
		if err := rs.save(r.Context(), st); err != nil {
			d.Logger.Warn("debate: cache verdicts", "err", err)
		}
	}

	rounds := make([]debateRoundView, 0, len(motions))
	myWins, partnerWins := 0, 0
	myDone, bothDone := true, true
	mySlot := "b"
	if userID == aID {
		mySlot = "a"
	}
	for _, m := range motions {
		v := debateRoundView{ID: m.ID, Motion: m.Prompt, MySide: "for"}
		if mine := byUser[userID][m.ID]; mine != "" {
			v.MyArgument = &mine
		} else {
			myDone = false
		}
		bothArgued := byUser[aID][m.ID] != "" && byUser[bID][m.ID] != ""
		if !bothArgued {
			bothDone = false
		}
		if v.MyArgument != nil && bothArgued {
			pa := byUser[partner.ID][m.ID]
			v.PartnerArgument = &pa
		}
		if vr, done := verdicts[m.ID]; done {
			v.Judged = true
			myScore, partnerScore := vr.BScore, vr.AScore
			if mySlot == "a" {
				myScore, partnerScore = vr.AScore, vr.BScore
			}
			v.MyScore = &myScore
			v.PartnerScore = &partnerScore
			var rw string
			switch {
			case vr.Winner == "tie":
				rw = "tie"
			case vr.Winner == mySlot:
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
	gen, motions, _, _, err := d.debateRoundMotions(r.Context(), c.ID, pack, langParam(r))
	if err != nil {
		d.serverError(w, "debate: round", err)
		return
	}
	valid := false
	for _, m := range motions {
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
	quizID := debateAnswerKey(pack.ID, gen)
	if err := d.Store.UpsertQuizAnswer(r.Context(), c.ID, quizID, req.RoundID, userID, argument); err != nil {
		d.serverError(w, "debate: save", err)
		return
	}
	d.notifyTurnOrResults(r.Context(), c.ID, userID, quizID,
		"Couples Debate", len(motions),
		"The judge has ruled on "+pack.Title+" — see who won 🏆",
		map[string]string{"type": "debate", "packId": pack.ID})
	w.WriteHeader(http.StatusNoContent)
}

// POST /v1/games/debate/packs/{id}/seen
//
// Called by the client when it opens the results screen. Once both partners
// have opened results for the current round *and* have both answered every
// motion, the round is retired: gen++, motions are regenerated by Claude, the
// pack becomes playable again with fresh content. If only one has seen so far
// the endpoint is a no-op besides the seen bookkeeping.
func (d Deps) handleSeenDebatePack(w http.ResponseWriter, r *http.Request) {
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

	gen, motions, st, rs, err := d.debateRoundMotions(r.Context(), c.ID, pack, langParam(r))
	if err != nil {
		d.serverError(w, "debate: round", err)
		return
	}
	// bothDone gates the rotation: never wipe an in-flight round even if both
	// tapped the results tab. The client should only call this endpoint when it
	// has actually shown reveal UI, but we defend against a stale call anyway.
	quizID := debateAnswerKey(pack.ID, gen)
	answers, err := d.Store.GetQuizAnswers(r.Context(), c.ID, quizID)
	if err != nil {
		d.serverError(w, "debate: answers", err)
		return
	}
	answered := make(map[string]map[string]bool)
	for _, a := range answers {
		if answered[a.UserID] == nil {
			answered[a.UserID] = make(map[string]bool)
		}
		answered[a.UserID][a.QuestionID] = true
	}
	bothDone := partner.ID != ""
	for _, m := range motions {
		if !answered[userID][m.ID] || (partner.ID != "" && !answered[partner.ID][m.ID]) {
			bothDone = false
			break
		}
	}
	if !bothDone {
		// Record seen anyway (harmless), but don't rotate yet.
		if !contains(st.SeenBy, userID) {
			st.SeenBy = append(st.SeenBy, userID)
			_ = rs.save(r.Context(), st)
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}

	_, bothSeen, err := rs.markSeen(r.Context(), userID, partner.ID)
	if err != nil {
		d.serverError(w, "debate: seen", err)
		return
	}
	if bothSeen {
		fresh := d.generateFreshDebateMotions(r.Context(), pack, langParam(r), gen+1)
		raw, _ := json.Marshal(debateRoundContent{Motions: fresh})
		if _, err := rs.bumpGeneration(r.Context(), raw); err != nil {
			d.serverError(w, "debate: bump", err)
			return
		}
	}
	w.WriteHeader(http.StatusNoContent)
}
