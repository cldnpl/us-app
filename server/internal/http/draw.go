package httpapi

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/sharepact/us/internal/push"
	"github.com/sharepact/us/internal/store"
)

// Draw Together: both partners get the same prompt and draw it on their own
// device. Neither drawing is revealed until both have submitted — then they're
// shown side by side. No scores. A round is a game_sessions row (game_type
// "draw", state holds the prompt); drawings live in draw_submissions.

const drawGameType = "draw"

// drawPrompts are the shared prompts a round can land on. Kept playful and
// couple-friendly — quick to sketch, fun to compare.
var drawPrompts = []string{
	"your partner as a superhero",
	"your dream house",
	"the perfect date night",
	"us on a desert island",
	"your partner's favourite food",
	"a monster under the bed",
	"our future pet",
	"the last thing that made you laugh",
	"a robot that does your least favourite chore",
	"your happy place",
	"us as cartoon characters",
	"breakfast in bed",
	"a plant that could talk",
	"the world's worst haircut",
	"our next holiday",
	"a cat wearing a tiny hat",
	"your partner mid-sneeze",
	"a spaceship built for two",
	"the best sandwich imaginable",
	"a dragon guarding a snack",
	"your favourite memory of us",
	"a grumpy cloud",
	"us slow dancing",
	"an alien tasting pizza for the first time",
}

func pickPrompt(exclude string) string {
	if len(drawPrompts) == 0 {
		return "anything you like"
	}
	i := int(time.Now().UnixNano()) % len(drawPrompts)
	if i < 0 {
		i += len(drawPrompts)
	}
	if drawPrompts[i] == exclude {
		i = (i + 1) % len(drawPrompts)
	}
	return drawPrompts[i]
}

type drawState struct {
	Prompt string `json:"prompt"`
}

type drawView struct {
	RoundID          string  `json:"roundId"`
	Prompt           string  `json:"prompt"`
	MySubmitted      bool    `json:"mySubmitted"`
	PartnerSubmitted bool    `json:"partnerSubmitted"`
	Revealed         bool    `json:"revealed"` // both submitted → drawings shown
	MyImagePath      *string `json:"myImagePath"`
	PartnerImagePath *string `json:"partnerImagePath"` // only once revealed
}

func drawImagePath(id string) string { return "/v1/games/draw/submissions/" + id + "/file" }

// currentRound returns the couple's active drawing round, creating one (with a
// fresh prompt) if none exists yet.
func (d Deps) currentRound(w http.ResponseWriter, r *http.Request, coupleID, userID string) (store.GameSession, bool) {
	g, err := d.Store.GetLatestGame(r.Context(), coupleID, drawGameType)
	if err == nil {
		return g, true
	}
	raw, _ := json.Marshal(drawState{Prompt: pickPrompt("")})
	g, err = d.Store.CreateGame(r.Context(), coupleID, drawGameType, raw, userID)
	if err != nil {
		d.serverError(w, "draw: create round", err)
		return store.GameSession{}, false
	}
	return g, true
}

func (d Deps) buildDrawView(r *http.Request, round store.GameSession, userID, partnerID string) (drawView, error) {
	var st drawState
	_ = json.Unmarshal(round.State, &st)

	subs, err := d.Store.GetDrawSubmissions(r.Context(), round.ID)
	if err != nil {
		return drawView{}, err
	}
	byUser := make(map[string]store.DrawSubmission, len(subs))
	for _, s := range subs {
		byUser[s.UserID] = s
	}

	v := drawView{RoundID: round.ID, Prompt: st.Prompt}
	if mine, ok := byUser[userID]; ok {
		v.MySubmitted = true
		p := drawImagePath(mine.ID)
		v.MyImagePath = &p
	}
	partnerSub, partnerOK := byUser[partnerID]
	v.PartnerSubmitted = partnerID != "" && partnerOK
	v.Revealed = v.MySubmitted && v.PartnerSubmitted
	if v.Revealed {
		p := drawImagePath(partnerSub.ID)
		v.PartnerImagePath = &p
	}
	return v, nil
}

// GET /v1/games/draw
func (d Deps) handleGetDraw(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	round, ok := d.currentRound(w, r, c.ID, userID)
	if !ok {
		return
	}
	v, err := d.buildDrawView(r, round, userID, partner.ID)
	if err != nil {
		d.serverError(w, "draw: view", err)
		return
	}
	writeJSON(w, http.StatusOK, v)
}

// POST /v1/games/draw/submit  (multipart: file)
func (d Deps) handleSubmitDraw(w http.ResponseWriter, r *http.Request) {
	userID, ok := d.authedUser(w, r)
	if !ok {
		return
	}
	c, ok := d.gameCouple(w, r, userID)
	if !ok {
		return
	}
	partner, _ := d.Store.GetPartner(r.Context(), c.ID, userID)
	round, ok := d.currentRound(w, r, c.ID, userID)
	if !ok {
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(maxUploadBytes + (1 << 20)); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_upload", "could not read the drawing")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing_file", "a drawing is required")
		return
	}
	defer file.Close()

	id := uuid.NewString()
	fullRel, thumbRel, _, err := d.Media.SaveImage(c.ID, id, file)
	if err != nil {
		d.Logger.Error("draw: save image failed", "err", err)
		writeError(w, http.StatusBadRequest, "bad_image", "could not process that drawing")
		return
	}

	// Replacing an earlier submission: remove the old files first.
	if prev, perr := d.Store.GetDrawSubmissionForUser(r.Context(), round.ID, userID); perr == nil {
		d.Media.Remove(prev.FilePath, prev.ThumbPath)
	}
	if err := d.Store.UpsertDrawSubmission(r.Context(), round.ID, userID, fullRel, thumbRel); err != nil {
		d.Media.Remove(fullRel, thumbRel)
		d.serverError(w, "draw: save submission", err)
		return
	}

	d.sendPartnerPush(r.Context(), c.ID, userID, func(name string) push.Notification {
		return push.Notification{
			Title: "🎨",
			Body:  name + " finished their drawing — your turn!",
			Data:  map[string]string{"type": "draw"},
		}
	})

	v, err := d.buildDrawView(r, round, userID, partner.ID)
	if err != nil {
		d.serverError(w, "draw: view", err)
		return
	}
	writeJSON(w, http.StatusCreated, v)
}

// POST /v1/games/draw/new — start a fresh round with a new prompt.
func (d Deps) handleNewDraw(w http.ResponseWriter, r *http.Request) {
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
	if g, err := d.Store.GetLatestGame(r.Context(), c.ID, drawGameType); err == nil {
		var st drawState
		_ = json.Unmarshal(g.State, &st)
		prev = st.Prompt
	}
	_ = d.Store.FinishActiveGames(r.Context(), c.ID, drawGameType)

	raw, _ := json.Marshal(drawState{Prompt: pickPrompt(prev)})
	round, err := d.Store.CreateGame(r.Context(), c.ID, drawGameType, raw, userID)
	if err != nil {
		d.serverError(w, "draw: new round", err)
		return
	}
	v, err := d.buildDrawView(r, round, userID, partner.ID)
	if err != nil {
		d.serverError(w, "draw: view", err)
		return
	}
	writeJSON(w, http.StatusCreated, v)
}

// GET /v1/games/draw/submissions/{id}/file — serve a drawing (couple-scoped).
func (d Deps) handleServeDrawing(w http.ResponseWriter, r *http.Request) {
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
