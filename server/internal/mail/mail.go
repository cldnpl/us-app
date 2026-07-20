// Package mail delivers transactional email (today: email-change codes).
//
// It mirrors the shape of internal/push: a small Sender interface with a
// log-only implementation for local development and a real one for production,
// chosen at startup from config. Nothing outside this package knows which is
// in use.
package mail

import (
	"context"
	"log/slog"
)

// Message is a single plain-text email.
type Message struct {
	To      string
	Subject string
	Body    string
}

// Sender delivers a message. Implementations must be safe for concurrent use.
type Sender interface {
	Send(ctx context.Context, m Message) error
	// Deliverable reports whether this sender actually puts mail in someone's
	// inbox. The log sender does not, which callers use to decide whether a
	// code has to be surfaced some other way in development.
	Deliverable() bool
}

type logSender struct{ logger *slog.Logger }

// NewLogSender returns a Sender that writes the message to the log instead of
// sending it. Used when no SMTP credentials are configured.
func NewLogSender(logger *slog.Logger) Sender { return logSender{logger: logger} }

func (l logSender) Send(_ context.Context, m Message) error {
	l.logger.Info("mail (not sent — no SMTP configured)",
		"to", m.To, "subject", m.Subject, "body", m.Body)
	return nil
}

func (l logSender) Deliverable() bool { return false }
