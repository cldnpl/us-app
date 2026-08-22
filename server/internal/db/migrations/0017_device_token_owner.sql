-- +goose Up
-- An APNs token identifies one install of the app on one phone, so it can only
-- belong to one account at a time. The old UNIQUE (user_id, apns_token) allowed
-- the same phone to stay registered under every account that had ever signed in
-- on it — and it then received that account's notifications too, which is how a
-- "miss you" sent to your partner could land on your own lock screen.

-- Keep only the most recently updated row per token.
DELETE FROM devices d
 USING devices newer
 WHERE d.apns_token = newer.apns_token
   AND (newer.updated_at, newer.id) > (d.updated_at, d.id);

ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_user_id_apns_token_key;
ALTER TABLE devices ADD CONSTRAINT devices_apns_token_key UNIQUE (apns_token);

-- +goose Down
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_apns_token_key;
ALTER TABLE devices ADD CONSTRAINT devices_user_id_apns_token_key UNIQUE (user_id, apns_token);
