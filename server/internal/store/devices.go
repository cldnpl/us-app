package store

import "context"

type DeviceToken struct {
	Token       string
	Environment string
}

// UpsertDevice records this install's APNs token against the signed-in user.
//
// The conflict is on the token alone, so registering hands the phone over to
// whoever is signed in on it now: a token belongs to one account at a time, and
// the previous owner stops receiving notifications meant for them on a phone
// that is no longer theirs.
func (s *Store) UpsertDevice(ctx context.Context, userID, apnsToken, platform, environment string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO devices (user_id, apns_token, platform, environment)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (apns_token)
		 DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform,
		               environment = EXCLUDED.environment, updated_at = now()`,
		userID, apnsToken, platform, environment)
	return err
}

func (s *Store) DeleteDevice(ctx context.Context, userID, apnsToken string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM devices WHERE user_id = $1 AND apns_token = $2`, userID, apnsToken)
	return err
}

func (s *Store) GetDeviceTokens(ctx context.Context, userID string) ([]DeviceToken, error) {
	rows, err := s.pool.Query(ctx, `SELECT apns_token, environment FROM devices WHERE user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []DeviceToken
	for rows.Next() {
		var d DeviceToken
		if err := rows.Scan(&d.Token, &d.Environment); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}
