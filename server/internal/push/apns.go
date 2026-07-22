package push

import (
	"context"
	"crypto/ecdsa"
	"fmt"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/payload"
	"github.com/sideshow/apns2/token"
)

type apnsSender struct {
	client *apns2.Client
	topic  string
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
	client := apns2.NewTokenClient(&token.Token{AuthKey: authKey, KeyID: keyID, TeamID: teamID})
	if production {
		client.Production()
	} else {
		client.Development()
	}
	return &apnsSender{client: client, topic: topic}, nil
}

func (s *apnsSender) Send(ctx context.Context, deviceTokens []string, n Notification) error {
	p := payload.NewPayload().AlertTitle(n.Title).AlertBody(n.Body).Sound("default")
	for k, v := range n.Data {
		p.Custom(k, v)
	}
	for _, deviceToken := range deviceTokens {
		res, err := s.client.PushWithContext(ctx, &apns2.Notification{
			DeviceToken: deviceToken,
			Topic:       s.topic,
			Payload:     p,
		})
		if err != nil {
			return err
		}
		if !res.Sent() {
			return fmt.Errorf("apns rejected (%d): %s", res.StatusCode, res.Reason)
		}
	}
	return nil
}
