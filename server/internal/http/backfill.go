package httpapi

import (
	"strings"
	"time"
)

// BackfillResult classifies what ResolveOptionID found for one quiz_answers
// row, so the caller (cmd/backfill-quiz-option-ids) knows whether to update
// the row, leave it alone, or log it as an exception.
type BackfillResult int

const (
	// BackfillNotFound means quizID/questionID don't resolve to any known
	// catalog content (stale/removed quiz or question) — leave untouched.
	BackfillNotFound BackfillResult = iota
	// BackfillNoChange means the question is open-type (free text, already
	// language-agnostic) or the stored answer already equals an option id
	// (already migrated, or produced by a build that already stored ids).
	BackfillNoChange
	// BackfillResolved means the stored answer matched an option's label and
	// NewAnswer is the option id it should be rewritten to.
	BackfillResolved
	// BackfillUnresolved means it's a choice question but the stored answer
	// matches neither an option id nor an option label (e.g. wording changed
	// since the answer was saved) — leave untouched, log for manual review.
	BackfillUnresolved
)

// ResolveOptionID converts a legacy label-text quiz_answers.answer into its
// stable option id, for the three quiz_id shapes this table stores: a plain
// catalog quiz id, "daily:<date>", or "hwdykm:<packID>". Exported solely for
// the one-off cmd/backfill-quiz-option-ids tool that migrates existing rows
// after catalogOption/hwdykmOption gained stable ids in place of label
// matching (see quiz_catalog.go/hwdykm_catalog.go doc comments for why).
func ResolveOptionID(quizID, questionID, answer string) (result BackfillResult, newAnswer string) {
	switch {
	case strings.HasPrefix(quizID, "daily:"):
		dateStr := strings.TrimPrefix(quizID, "daily:")
		t, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			return BackfillNotFound, ""
		}
		_, _, q := dailyPick(t, quizCatalog)
		if q.ID != questionID {
			return BackfillNotFound, ""
		}
		return resolveChoiceOptions(q.Type == qTypeChoice, q.Options, answer)

	case strings.HasPrefix(quizID, "hwdykm:"):
		packID := strings.TrimPrefix(quizID, "hwdykm:")
		pack, found := findHwdykmPack(packID)
		if !found {
			return BackfillNotFound, ""
		}
		for _, q := range pack.Questions {
			if q.ID != questionID {
				continue
			}
			for _, o := range q.Options {
				if o.ID == answer {
					return BackfillNoChange, ""
				}
				if o.Label == answer {
					return BackfillResolved, o.ID
				}
			}
			return BackfillUnresolved, ""
		}
		return BackfillNotFound, ""

	default:
		quiz, found := findQuiz(quizID)
		if !found {
			return BackfillNotFound, ""
		}
		q, found := quiz.question(questionID)
		if !found {
			return BackfillNotFound, ""
		}
		return resolveChoiceOptions(q.Type == qTypeChoice, q.Options, answer)
	}
}

func resolveChoiceOptions(isChoice bool, options []catalogOption, answer string) (BackfillResult, string) {
	if !isChoice {
		return BackfillNoChange, ""
	}
	for _, o := range options {
		if o.ID == answer {
			return BackfillNoChange, ""
		}
	}
	for _, o := range options {
		if o.Label == answer {
			return BackfillResolved, o.ID
		}
	}
	return BackfillUnresolved, ""
}
