package judge

import (
	"context"
	"testing"
)

// With no API key, Score uses the heuristic and never hits the network.
func offlineJudge() *Judge { return New("", "") }

func TestHeuristicRewardsSubstance(t *testing.T) {
	strong := "Pineapple works because the sweetness balances the salty cheese. For example, ham-and-pineapple pizza is a classic, so the combination is clearly proven."
	weak := "no"
	v := offlineJudge().Score(context.Background(), "Pineapple belongs on pizza.", strong, weak, "")
	if v.Winner != "a" {
		t.Fatalf("expected partner A to win, got %q (%d vs %d)", v.Winner, v.AScore, v.BScore)
	}
	if v.AScore <= v.BScore {
		t.Fatalf("expected aScore > bScore, got %d vs %d", v.AScore, v.BScore)
	}
	if v.Reason == "" {
		t.Fatal("expected a non-empty reason")
	}
}

func TestHeuristicScoresStayInRange(t *testing.T) {
	long := ""
	for i := 0; i < 500; i++ {
		long += "because example however "
	}
	v := offlineJudge().Score(context.Background(), "m", long, long, "")
	for _, s := range []int{v.AScore, v.BScore} {
		if s < 0 || s > 10 {
			t.Fatalf("score out of range: %d", s)
		}
	}
	if v.Winner != "tie" {
		t.Fatalf("equal arguments should tie, got %q", v.Winner)
	}
}

// Both partners always answer the same prompt: swapping the two answers must
// swap the winner and nothing else — the judge has no fixed "for"/"against".
func TestScoreIsSymmetric(t *testing.T) {
	strong := "It works because the sweetness balances the salt. For example, ham and pineapple is a classic, so the pairing is proven."
	weak := "nope"
	j := offlineJudge()
	ab := j.Score(context.Background(), "Same prompt for both.", strong, weak, "")
	ba := j.Score(context.Background(), "Same prompt for both.", weak, strong, "")
	if ab.Winner != "a" || ba.Winner != "b" {
		t.Fatalf("expected the stronger case to win either way, got %q then %q", ab.Winner, ba.Winner)
	}
	if ab.AScore != ba.BScore || ab.BScore != ba.AScore {
		t.Fatalf("scores should mirror: %+v vs %+v", ab, ba)
	}
}

func TestClampFillsWinnerFromScores(t *testing.T) {
	v := clamp(Verdict{AScore: 12, BScore: -3, Winner: ""})
	if v.AScore != 10 || v.BScore != 0 {
		t.Fatalf("clamp failed: %+v", v)
	}
	if v.Winner != "a" {
		t.Fatalf("expected winner inferred as 'a', got %q", v.Winner)
	}
}
