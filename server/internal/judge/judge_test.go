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
	v := offlineJudge().Score(context.Background(), "Pineapple belongs on pizza.", strong, weak)
	if v.Winner != "for" {
		t.Fatalf("expected 'for' to win, got %q (%d vs %d)", v.Winner, v.ForScore, v.AgainstScore)
	}
	if v.ForScore <= v.AgainstScore {
		t.Fatalf("expected forScore > againstScore, got %d vs %d", v.ForScore, v.AgainstScore)
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
	v := offlineJudge().Score(context.Background(), "m", long, long)
	for _, s := range []int{v.ForScore, v.AgainstScore} {
		if s < 0 || s > 10 {
			t.Fatalf("score out of range: %d", s)
		}
	}
	if v.Winner != "tie" {
		t.Fatalf("equal arguments should tie, got %q", v.Winner)
	}
}

func TestClampFillsWinnerFromScores(t *testing.T) {
	v := clamp(Verdict{ForScore: 12, AgainstScore: -3, Winner: ""})
	if v.ForScore != 10 || v.AgainstScore != 0 {
		t.Fatalf("clamp failed: %+v", v)
	}
	if v.Winner != "for" {
		t.Fatalf("expected winner inferred as 'for', got %q", v.Winner)
	}
}
