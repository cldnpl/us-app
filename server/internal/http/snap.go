package httpapi

import (
	"encoding/json"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/sharepact/us/internal/judge"
	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// Snap Hunt: the app calls a loose clue; both partners race to find something
// at home that fits, snap a photo, and an AI judge crowns the cleverest find.
// A hunt is a game_sessions row (game_type "snap", state holds the clue and,
// once judged, the winner). Photos reuse the draw_submissions table (keyed by
// round id) so they never appear in the couple's gallery.

const snapGameType = "snap"

var snapClues = []string{
	"something round",
	"something that smells nice",
	"something older than both of you",
	"something that makes you smile",
	"something red",
	"the coziest thing you own",
	"something you'd grab in a fire",
	"something soft",
	"the weirdest thing in your fridge",
	"something that reminds you of the other",
	"something shiny",
	"a tiny treasure",
	"something you never use",
	"something green and alive",
	"the most useless gadget you own",
	"something that makes noise",
	"something from a trip you took",
	"something handmade",
	"the most colourful thing nearby",
	"something that could be a hat",
	"something you've had since childhood",
	"the comfiest seat in the house",
	"something that fits in one hand",
	"something worth more than it looks",
}

func pickClue(exclude string) string {
	if len(snapClues) == 0 {
		return "something interesting"
	}
	i := int(time.Now().UnixNano()) % len(snapClues)
	if i < 0 {
		i += len(snapClues)
	}
	if snapClues[i] == exclude {
		i = (i + 1) % len(snapClues)
	}
	return snapClues[i]
}

type snapVerdict struct {
	WinnerUserID string `json:"winnerUserId"` // user id, or "tie"
	Reason       string `json:"reason"`
}

type snapState struct {
	Clue    string       `json:"clue"`
	Verdict *snapVerdict `json:"verdict,omitempty"`
}

type snapView struct {
	RoundID          string  `json:"roundId"`
	Clue             string  `json:"clue"`
	MySubmitted      bool    `json:"mySubmitted"`
	PartnerSubmitted bool    `json:"partnerSubmitted"`
	Revealed         bool    `json:"revealed"`
	MyImagePath      *string `json:"myImagePath"`
	PartnerImagePath *string `json:"partnerImagePath"`
	Outcome          *string `json:"outcome"` // "me" | "partner" | "tie", when revealed
	Reason           *string `json:"reason"`
}

func snapImagePath(id string) string { return "/v1/games/snap/submissions/" + id + "/file" }

func (d Deps) currentHunt(w http.ResponseWriter, r *http.Request, coupleID, userID string) (store.GameSession, bool) {
	g, err := d.Store.GetLatestGame(r.Context(), coupleID, snapGameType)
	if err == nil {
		return g, true
	}
	raw, _ := json.Marshal(snapState{Clue: pickClue("")})
	g, err = d.Store.CreateGame(r.Context(), coupleID, snapGameType, raw, userID)
	if err != nil {
		d.serverError(w, "snap: create hunt", err)
		return store.GameSession{}, false
	}
	return g, true
}

// buildSnapView judges the round if both photos are in and no verdict is cached,
// persists the verdict, and returns the caller's view.
func (d Deps) buildSnapView(r *http.Request, round store.GameSession, userID, partnerID string) (snapView, error) {
	var st snapState
	_ = json.Unmarshal(round.State, &st)

	subs, err := d.Store.GetDrawSubmissions(r.Context(), round.ID)
	if err != nil {
		return snapView{}, err
	}
	byUser := make(map[string]store.DrawSubmission, len(subs))
	for _, s := range subs {
		byUser[s.UserID] = s
	}

	mine, iSubmitted := byUser[userID]
	partnerSub, partnerSubmitted := byUser[partnerID]
	partnerSubmitted = partnerID != "" && partnerSubmitted
	revealed := iSubmitted && partnerSubmitted

	// Judge once both are in; cache the winner on the round so both see the same.
	if revealed && st.Verdict == nil {
		aID, bID := orderedIDs(userID, partnerID)
		a, aok := byUser[aID]
		b, bok := byUser[bID]
		if aok && bok {
			imgA, errA := os.ReadFile(d.Media.Abs(a.FilePath))
			imgB, errB := os.ReadFile(d.Media.Abs(b.FilePath))
			if errA == nil && errB == nil {
				v := d.snapJudge().ScoreSnaps(r.Context(), st.Clue,
					judge.SnapImage{Data: imgA, MediaType: "image/jpeg"},
					judge.SnapImage{Data: imgB, MediaType: "image/jpeg"})
				winner := "tie"
				switch v.Winner {
				case "a":
					winner = aID
				case "b":
					winner = bID
				}
				st.Verdict = &snapVerdict{WinnerUserID: winner, Reason: v.Reason}
				if raw, mErr := json.Marshal(st); mErr == nil {
					if _, uErr := d.Store.UpdateGame(r.Context(), round.ID, raw, nil, "active"); uErr != nil {
						d.Logger.Warn("snap: cache verdict", "err", uErr)
					}
				}
			}
		}
	}

	v := snapView{
		RoundID: round.ID, Clue: st.Clue,
		MySubmitted: iSubmitted, PartnerSubmitted: partnerSubmitted, Revealed: revealed,
	}
	if iSubmitted {
		p := snapImagePath(mine.ID)
		v.MyImagePath = &p
	}
	if revealed {
		p := snapImagePath(partnerSub.ID)
		v.PartnerImagePath = &p
		if st.Verdict != nil {
			outcome := "tie"
			if st.Verdict.WinnerUserID == userID {
				outcome = "me"
			} else if st.Verdict.WinnerUserID != "tie" && st.Verdict.WinnerUserID != "" {
				outcome = "partner"
			}
			reason := st.Verdict.Reason
			v.Outcome = &outcome
			v.Reason = &reason
		}
	}
	return v, nil
}

func (d Deps) snapJudge() *judge.Judge {
	return judge.New(d.Config.AnthropicAPIKey, d.Config.AnthropicModel)
}

// GET /v1/games/snap
func (d Deps) handleGetSnap(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	round, ok := d.currentHunt(w, r, c.ID, userID)
	if !ok {
		return
	}
	v, err := d.buildSnapView(r, round, userID, partner.ID)
	if err != nil {
		d.serverError(w, "snap: view", err)
		return
	}
	writeJSON(w, http.StatusOK, v)
}

// POST /v1/games/snap/submit  (multipart: file)
func (d Deps) handleSubmitSnap(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	round, ok := d.currentHunt(w, r, c.ID, userID)
	if !ok {
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(maxUploadBytes + (1 << 20)); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_upload", "could not read the photo")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing_file", "a photo is required")
		return
	}
	defer file.Close()

	id := uuid.NewString()
	fullRel, thumbRel, _, err := d.Media.SaveImage(c.ID, id, file)
	if err != nil {
		d.Logger.Error("snap: save image failed", "err", err)
		writeError(w, http.StatusBadRequest, "bad_image", "could not process that photo")
		return
	}
	if prev, perr := d.Store.GetDrawSubmissionForUser(r.Context(), round.ID, userID); perr == nil {
		d.Media.Remove(prev.FilePath, prev.ThumbPath)
	}
	if err := d.Store.UpsertDrawSubmission(r.Context(), round.ID, userID, fullRel, thumbRel); err != nil {
		d.Media.Remove(fullRel, thumbRel)
		d.serverError(w, "snap: save submission", err)
		return
	}

	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{
			Title: "📸",
			Body:  name + " snapped their find — go hunt!",
			Data:  map[string]string{"type": "snap"},
		}
	})

	v, err := d.buildSnapView(r, round, userID, partner.ID)
	if err != nil {
		d.serverError(w, "snap: view", err)
		return
	}
	writeJSON(w, http.StatusCreated, v)
}

// POST /v1/games/snap/new — start a fresh hunt with a new clue.
func (d Deps) handleNewSnap(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)

	prev := ""
	if g, err := d.Store.GetLatestGame(r.Context(), c.ID, snapGameType); err == nil {
		var st snapState
		_ = json.Unmarshal(g.State, &st)
		prev = st.Clue
	}
	_ = d.Store.FinishActiveGames(r.Context(), c.ID, snapGameType)

	raw, _ := json.Marshal(snapState{Clue: pickClue(prev)})
	round, err := d.Store.CreateGame(r.Context(), c.ID, snapGameType, raw, userID)
	if err != nil {
		d.serverError(w, "snap: new hunt", err)
		return
	}
	v, err := d.buildSnapView(r, round, userID, partner.ID)
	if err != nil {
		d.serverError(w, "snap: view", err)
		return
	}
	writeJSON(w, http.StatusCreated, v)
}

// GET /v1/games/snap/submissions/{id}/file — serve a photo (couple-scoped).
func (d Deps) handleServeSnap(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	filePath, coupleID, err := d.Store.GetDrawSubmissionOwned(r.Context(), chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "not found")
		return
	}
	c, err := d.Store.GetCoupleForUser(r.Context(), userID)
	if err != nil || c.ID != coupleID {
		writeError(w, http.StatusForbidden, "forbidden", "not allowed")
		return
	}
	w.Header().Set("Cache-Control", "private, max-age=86400")
	http.ServeFile(w, r, d.Media.Abs(filePath))
}
