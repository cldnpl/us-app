// Package push delivers notifications to user devices. The Sender interface lets
// the app run with a log-only sender in development and a real APNs sender once
// Apple credentials are configured.
package push

import (
	"context"
	"log/slog"
)

type Notification struct {
	Title string
	Body  string
	Data  map[string]string
}

type Sender interface {
	Send(ctx context.Context, deviceTokens []string, n Notification) error
}

type logSender struct{ logger *slog.Logger }

// NewLogSender returns a Sender that only logs — used until APNs is configured.
func NewLogSender(logger *slog.Logger) Sender { return &logSender{logger: logger} }

func (s *logSender) Send(_ context.Context, deviceTokens []string, n Notification) error {
	s.logger.Info("push (log-only)", "recipients", len(deviceTokens), "title", n.Title, "body", n.Body)
	return nil
}
