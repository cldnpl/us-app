// Command backfill-quiz-option-ids is a one-off, safely-rerunnable tool that
// rewrites existing quiz_answers rows from label text to the stable option
// ids introduced alongside catalogOption/hwdykmOption (see
// internal/http/quiz_catalog.go and hwdykm_catalog.go). Run it once against
// each environment's database after deploying that change and before
// translating any catalog content — matching by label breaks the moment
// labels are localized or reworded.
//
// Usage: DATABASE_URL=... go run ./cmd/backfill-quiz-option-ids [-dry-run]
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sharepact/us/internal/config"
	"github.com/sharepact/us/internal/db"
	httpapi "github.com/sharepact/us/internal/http"
)

type answerRow struct {
	id         string
	quizID     string
	questionID string
	answer     string
}

func main() {
	dryRun := flag.Bool("dry-run", false, "log what would change without writing")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	if err := run(logger, *dryRun); err != nil {
		logger.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger, dryRun bool) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	ctx := context.Background()

	pool, err := db.Connect(ctx, cfg.DatabaseURL, logger)
	if err != nil {
		return err
	}
	defer pool.Close()

	rows, err := pool.Query(ctx, `SELECT id, quiz_id, question_id, answer FROM quiz_answers ORDER BY quiz_id, question_id`)
	if err != nil {
		return fmt.Errorf("query quiz_answers: %w", err)
	}
	var all []answerRow
	for rows.Next() {
		var r answerRow
		if err := rows.Scan(&r.id, &r.quizID, &r.questionID, &r.answer); err != nil {
			rows.Close()
			return fmt.Errorf("scan row: %w", err)
		}
		all = append(all, r)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate rows: %w", err)
	}

	logger.Info("loaded quiz_answers", "count", len(all))

	var resolved, unchanged, unresolved, notFound int
	for _, r := range all {
		result, newAnswer := httpapi.ResolveOptionID(r.quizID, r.questionID, r.answer)
		switch result {
		case httpapi.BackfillNoChange:
			unchanged++
		case httpapi.BackfillNotFound:
			notFound++
			logger.Warn("quiz/question not found in catalog — leaving row untouched",
				"id", r.id, "quizId", r.quizID, "questionId", r.questionID)
		case httpapi.BackfillUnresolved:
			unresolved++
			logger.Warn("answer matches neither an option id nor an option label — leaving row untouched",
				"id", r.id, "quizId", r.quizID, "questionId", r.questionID, "answer", r.answer)
		case httpapi.BackfillResolved:
			resolved++
			logger.Info("resolving label to option id",
				"id", r.id, "quizId", r.quizID, "questionId", r.questionID,
				"from", r.answer, "to", newAnswer)
			if !dryRun {
				if err := updateAnswer(ctx, pool, r.id, newAnswer); err != nil {
					return fmt.Errorf("update row %s: %w", r.id, err)
				}
			}
		}
	}

	logger.Info("done",
		"resolved", resolved, "unchanged", unchanged,
		"unresolved", unresolved, "notFound", notFound, "dryRun", dryRun)
	if unresolved > 0 || notFound > 0 {
		logger.Warn("some rows were left untouched — review the warnings above")
	}
	return nil
}

func updateAnswer(ctx context.Context, pool *pgxpool.Pool, id, newAnswer string) error {
	_, err := pool.Exec(ctx, `UPDATE quiz_answers SET answer = $1 WHERE id = $2`, newAnswer, id)
	return err
}
