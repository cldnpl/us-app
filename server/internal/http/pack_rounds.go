package httpapi

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/sharepact/us/internal/store"
)

// A "pack round" is one generation of a per-couple, per-pack replayable game
// (Couples Debate, How Well Do You Know Me). Each round owns:
//
//   - a monotonically increasing generation number;
//   - the LLM-generated content for this generation (motions or questions);
//   - a `seenBy` list — the user ids that have opened the results screen for
//     this generation; once both partners are in the list *and* both have
//     answered every question, the round is retired and the next fetch
//     produces a fresh generation with new content.
//
// Answers still live in `quiz_answers`, keyed by a composite quiz_id
// `<featureKey>:<packID>:g<gen>` so previous generations remain in the DB
// (searchable, but ignored by the current round's math).
//
// State is persisted per (couple, gameType) in a `game_sessions` row where
// gameType is e.g. `debate_pack:hot_takes`. The row is created on first
// access and updated in place from then on.

type packRoundState struct {
	Generation int             `json:"gen"`
	Content    json.RawMessage `json:"content,omitempty"`  // feature-defined payload
	SeenBy     []string        `json:"seenBy,omitempty"`   // user ids that opened results
	Verdicts   json.RawMessage `json:"verdicts,omitempty"` // feature-defined cache
}

// packRoundStore is a small wrapper around the game_sessions row for a pack.
type packRoundStore struct {
	Deps      Deps
	CoupleID  string
	GameType  string
	sessionID string // populated once loaded/created
	state     packRoundState
}

func (d Deps) packRound(coupleID, gameType string) *packRoundStore {
	return &packRoundStore{Deps: d, CoupleID: coupleID, GameType: gameType}
}

// load reads the current round; if none exists, returns a zero state with
// Generation == 0. Callers detect the "no round yet" case by checking
// Generation and then initialize with initialize().
func (p *packRoundStore) load(ctx context.Context) error {
	g, err := p.Deps.Store.GetLatestGame(ctx, p.CoupleID, p.GameType)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return nil
		}
		return err
	}
	p.sessionID = g.ID
	if len(g.State) > 0 {
		_ = json.Unmarshal(g.State, &p.state)
	}
	return nil
}

// current returns the loaded state. Call load() first.
func (p *packRoundStore) current() packRoundState { return p.state }

// initialize seeds generation 1 with the given content. Returns the persisted
// state so callers can use its Generation etc.
func (p *packRoundStore) initialize(ctx context.Context, userID string, content json.RawMessage) (packRoundState, error) {
	st := packRoundState{Generation: 1, Content: content}
	raw, _ := json.Marshal(st)
	g, err := p.Deps.Store.CreateGame(ctx, p.CoupleID, p.GameType, raw, userID)
	if err != nil {
		// Two phones racing to first-load the same pack: the loser sees a unique
		// constraint (if any) or an idempotent no-op — either way, refetch what's
		// there so both devices settle on the same round.
		if latest, latestErr := p.Deps.Store.GetLatestGame(ctx, p.CoupleID, p.GameType); latestErr == nil {
			p.sessionID = latest.ID
			_ = json.Unmarshal(latest.State, &p.state)
			return p.state, nil
		}
		return packRoundState{}, err
	}
	p.sessionID = g.ID
	p.state = st
	return st, nil
}

// save persists the given state as the current round.
func (p *packRoundStore) save(ctx context.Context, st packRoundState) error {
	raw, _ := json.Marshal(st)
	if p.sessionID == "" {
		g, err := p.Deps.Store.CreateGame(ctx, p.CoupleID, p.GameType, raw, "")
		if err != nil {
			return err
		}
		p.sessionID = g.ID
	} else {
		if _, err := p.Deps.Store.UpdateGame(ctx, p.sessionID, raw, nil, "active"); err != nil {
			return err
		}
	}
	p.state = st
	return nil
}

// markSeen records that userID has opened the results for the current round.
// Returns (updated state, true) if both partners have now seen results, and
// caller should bump the generation with fresh content.
func (p *packRoundStore) markSeen(ctx context.Context, userID, partnerID string) (packRoundState, bool, error) {
	st := p.state
	if !contains(st.SeenBy, userID) {
		st.SeenBy = append(st.SeenBy, userID)
	}
	bothSeen := partnerID != "" && contains(st.SeenBy, userID) && contains(st.SeenBy, partnerID)
	if err := p.save(ctx, st); err != nil {
		return st, false, err
	}
	return st, bothSeen, nil
}

// bumpGeneration retires the current round: increments the generation, swaps
// in fresh content, and clears seenBy + verdicts. The composite quiz_id used
// by callers therefore changes (`…:g<oldGen>` → `…:g<newGen>`), and previously
// stored answers are naturally ignored by the next fetch.
func (p *packRoundStore) bumpGeneration(ctx context.Context, freshContent json.RawMessage) (packRoundState, error) {
	st := p.state
	st.Generation++
	if st.Generation < 1 {
		st.Generation = 1
	}
	st.Content = freshContent
	st.SeenBy = nil
	st.Verdicts = nil
	return st, p.save(ctx, st)
}

func contains(list []string, v string) bool {
	for _, s := range list {
		if s == v {
			return true
		}
	}
	return false
}
