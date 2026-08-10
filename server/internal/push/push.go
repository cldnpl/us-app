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
	// Silent sends a background (content-available) push: no banner, no sound.
	// It only wakes the app so it can refresh — used for location updates that
	// keep the distance widget current without the user opening anything.
	Silent bool
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
