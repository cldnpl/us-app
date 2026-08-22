package push

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"strings"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/payload"
	"github.com/sideshow/apns2/token"
)

type apnsSender struct {
	// Both APNs hosts. A device token is only valid on one of them, and which
	// one depends on how the build was signed — a TestFlight build's token is a
	// production token even while the same source runs in the sandbox from
	// Xcode. Rather than trust one flag for every device, we try the configured
	// host first and fall back to the other when APNs says the token is for the
	// other environment.
	primary  *apns2.Client
	fallback *apns2.Client
	topic    string
}

// NewAPNsSender builds a token-authenticated (.p8) APNs sender. It is only
// constructed when APNS credentials are present in config. The key arrives
// either as a file path or as raw PEM bytes (APNS_KEY_BASE64, for hosts like
// Railway that only support env vars, not secret files).
func NewAPNsSender(keyPath string, keyPEM []byte, keyID, teamID, topic string, production bool) (Sender, error) {
	var (
		authKey *ecdsa.PrivateKey
		err     error
	)
	if len(keyPEM) > 0 {
		authKey, err = token.AuthKeyFromBytes(keyPEM)
	} else {
		authKey, err = token.AuthKeyFromFile(keyPath)
	}
	if err != nil {
		return nil, err
	}
	tok := &token.Token{AuthKey: authKey, KeyID: keyID, TeamID: teamID}
	prod := apns2.NewTokenClient(tok).Production()
	dev := apns2.NewTokenClient(tok).Development()
	if production {
		return &apnsSender{primary: prod, fallback: dev, topic: topic}, nil
	}
	return &apnsSender{primary: dev, fallback: prod, topic: topic}, nil
}

func (s *apnsSender) Send(ctx context.Context, deviceTokens []string, n Notification) error {
	silent := n.Silent || (n.Title == "" && n.Body == "")
	var p *payload.Payload
	if silent {
		// Background push: content-available only, so iOS wakes the app to
		// refresh without showing anything.
		p = payload.NewPayload().ContentAvailable()
	} else {
		p = payload.NewPayload().AlertTitle(n.Title).AlertBody(n.Body).Sound("default")
	}
	for k, v := range n.Data {
		p.Custom(k, v)
	}
	pushType := apns2.PushTypeAlert
	priority := apns2.PriorityHigh
	if silent {
		// APNs requires background pushes to be declared and sent at low
		// priority; alert priority on a silent push is rejected.
		pushType = apns2.PushTypeBackground
		priority = apns2.PriorityLow
	}
	// One bad token must not swallow the rest of the batch: a couple has two
	// phones, and a stale token on one used to stop the other from being told
	// anything. Failures are collected and reported after every token is tried.
	var failures []string
	for _, deviceToken := range deviceTokens {
		n := &apns2.Notification{
			DeviceToken: deviceToken,
			Topic:       s.topic,
			Payload:     p,
			PushType:    pushType,
			Priority:    priority,
		}
		res, err := s.primary.PushWithContext(ctx, n)
		if err == nil && res.Reason == apns2.ReasonBadDeviceToken {
			// Right token, wrong host — this device belongs to the other
			// environment (TestFlight vs a local Xcode build).
			res, err = s.fallback.PushWithContext(ctx, n)
		}
		switch {
		case err != nil:
			failures = append(failures, err.Error())
		case !res.Sent():
			failures = append(failures, fmt.Sprintf("rejected (%d): %s", res.StatusCode, res.Reason))
		}
	}
	if len(failures) > 0 {
		return fmt.Errorf("apns: %d/%d failed: %s",
			len(failures), len(deviceTokens), strings.Join(failures, "; "))
	}
	return nil
}
