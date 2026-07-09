-- +goose Up
-- Per-couple answers to catalog quizzes. Quiz/question ids are stable string
-- keys defined by the static catalog in the Go code (not FK'd to a table), so
-- content can evolve in code without a migration. Same async-compare model as
-- question_answers: each partner answers independently, the other's answer is
-- revealed per-question only after you've answered it.
CREATE TABLE quiz_answers (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id   uuid NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    quiz_id     text NOT NULL,
    question_id text NOT NULL,
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answer      text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (couple_id, quiz_id, question_id, user_id)
);
CREATE INDEX idx_quiz_answers_couple ON quiz_answers(couple_id, quiz_id);

-- +goose Down
DROP TABLE IF EXISTS quiz_answers;
