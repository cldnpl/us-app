package httpapi

import (
	"context"
	"time"

	"github.com/sharepact/us/internal/push"
)

// How often the daily job wakes up to see whether today's nudge is still owed.
// Short enough that a server started mid-morning still sends today's, cheap
// enough to ignore: one small query per tick, and the claim below makes every
// tick after the first a no-op.
const dailyJobInterval = 15 * time.Minute

// StartDailyJobs runs the notifications nobody's request can trigger — today,
// just the Question of the Day. It returns immediately; the loop stops with ctx.
//
// The send is claimed per couple through notification_marks, so a restart, a
// redeploy, or a second instance can't send the same day twice.
func (d Deps) StartDailyJobs(ctx context.Context) {
	// Logged at boot so the deploy logs say plainly that the scheduled side of
	// notifications is alive, and from which hour it will fire.
	d.Logger.Info("daily notification jobs started", "questionHourUTC", d.Config.DailyQuestionHourUTC)
	go func() {
		ticker := time.NewTicker(dailyJobInterval)
		defer ticker.Stop()
		for {
			d.runDailyQuestionNudge(ctx)
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}

func (d Deps) runDailyQuestionNudge(ctx context.Context) {
	now := time.Now().UTC()
	if now.Hour() < d.Config.DailyQuestionHourUTC {
		return // too early where the couples are; wait for the next tick
	}
	couples, err := d.Store.ListActiveCouples(ctx)
	if err != nil {
		d.Logger.Warn("daily question: list couples", "err", err)
		return
	}
	_, _, question := dailyPick(now)
	key := dailyKey(now)

	for _, c := range couples {
		// Don't nag a couple who already answered today's question.
		if answers, err := d.Store.GetQuizAnswers(ctx, c.ID, key); err == nil && len(answers) >= 2 {
			continue
		}
		claimed, err := d.Store.ClaimNotification(ctx, c.ID, "daily_question", dailyNotifyWindow)
		if err != nil {
			d.Logger.Warn("daily question: claim", "couple", c.ID, "err", err)
			continue
		}
		if !claimed {
			continue
		}
		members, err := d.Store.GetCoupleMembers(ctx, c.ID)
		if err != nil {
			continue
		}
		var tokens []string
		for _, m := range members {
			devices, err := d.Store.GetDeviceTokens(ctx, m.ID)
			if err != nil {
				continue
			}
			for _, t := range devices {
				tokens = append(tokens, t.Token)
			}
		}
		if len(tokens) == 0 {
			continue
		}
		// The question itself is the body — it's the whole invitation.
		if err := d.Push.Send(ctx, tokens, push.Notification{
			Title: "Question of the Day",
			Body:  question.Prompt,
			Data:  map[string]string{"type": "daily_question"},
		}); err != nil {
			d.Logger.Warn("daily question: push", "couple", c.ID, "err", err)
		}
	}
}
