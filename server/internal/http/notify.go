package httpapi

import (
	"context"
	"time"

	"github.com/sharepact/us/internal/push"
)

// Notification cooldowns. Saving a diary entry with photos fires one request
// per photo, so without a window the partner's phone would buzz six times for
// one page of the diary.
const (
	journalNotifyWindow = 10 * time.Minute
	dailyNotifyWindow   = 20 * time.Hour
)

// notifyPartnerOnce is sendPartnerPush with a per-couple cooldown: repeated
// events of the same `kind` inside `window` produce a single notification.
func (d Deps) notifyPartnerOnce(ctx context.Context, coupleID, senderID, kind string,
	window time.Duration, build func(senderName string) push.Notification) {
	claimed, err := d.Store.ClaimNotification(ctx, coupleID, kind, window)
	if err != nil {
		d.Logger.Warn("notify: claim failed", "kind", kind, "err", err)
		return
	}
	if !claimed {
		return
	}
	d.sendPartnerPush(ctx, coupleID, senderID, build)
}

// notifyTurnOrResults is the nudge for the shared answer-then-compare games
// (quizzes, Know Me packs, debates), all of which store their answers in
// quiz_answers under `answerKey`.
//
// It stays silent while the caller is still working through the questions, and
// speaks once they've answered the last one — because a buzz per answer is what
// people mute. What it then says depends on who's left: "your turn" if the
// partner hasn't played it, "the results are in" if they already have.
func (d Deps) notifyTurnOrResults(ctx context.Context, coupleID, userID, answerKey, title string,
	total int, resultsLine string, data map[string]string) {
	if total <= 0 {
		return
	}
	keys, err := d.Store.GetQuizAnswerKeys(ctx, coupleID)
	if err != nil {
		return
	}
	counts := completionByUser(keys)
	if counts[answerKey][userID] < total {
		return // still mid-way: nothing to announce
	}
	partner, err := d.Store.GetPartner(ctx, coupleID, userID)
	if err != nil {
		return
	}
	bothDone := counts[answerKey][partner.ID] >= total

	d.sendPartnerPush(ctx, coupleID, userID, func(name string) push.Notification {
		body := name + " finished — your turn!"
		state := "turn"
		if bothDone {
			body = resultsLine
			state = "results"
		}
		return push.Notification{Title: title, Body: body, Data: withState(data, state)}
	})
}

// withState copies the routing payload and tags it with what happened, so the
// app can tell "come and play" from "come and look" when it handles the tap.
func withState(data map[string]string, state string) map[string]string {
	out := make(map[string]string, len(data)+1)
	for k, v := range data {
		out[k] = v
	}
	out["state"] = state
	return out
}
