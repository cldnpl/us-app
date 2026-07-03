package push

import (
	"context"
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
// constructed when APNS credentials are present in config.
func NewAPNsSender(keyPath, keyID, teamID, topic string, production bool) (Sender, error) {
	authKey, err := token.AuthKeyFromFile(keyPath)
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
