# Apple Developer Setup — Us.

Everything you need to enable Sign in with Apple, push, and the €0.99/mo subscription.
Bundle id: **`us.elbek.com`**.

## 1. App ID + Capabilities (developer.apple.com → Certificates, IDs & Profiles)
Create/enable an App ID `us.elbek.com` with:
- ✅ **Push Notifications**
- ✅ **Sign in with Apple**
- ✅ **App Groups** → create `group.us.elbek.com` (used by the widget)
- ✅ **In-App Purchase** (on by default)

The **widget** has its own App ID **`us.elbek.com.widget`** — enable **App Groups** on it too (same `group.us.elbek.com`) so the app and widget share data. Xcode's automatic signing creates the App ID on first device build; just confirm the App Group capability is checked on both the app and the widget target.

## 2. APNs Auth Key (.p8) — for push
- Keys → **+** → enable **Apple Push Notifications service (APNs)** → download the `.p8` (once only).
- Note the **Key ID** and your **Team ID**.
- On the server, drop the key and point the API at it:
  ```bash
  scp -i ~/.ssh/us_deploy_ed25519 AuthKey_XXXX.p8 root@155.138.228.111:/opt/us/AuthKey.p8
  # then add to /opt/us/.env:
  #   APNS_KEY_ID=XXXX
  #   APNS_TEAM_ID=YYYY
  # and mount the key + set APNS_KEY_PATH=/app/secrets/AuthKey.p8 in docker-compose.prod.yml
  # then: docker compose -f docker-compose.prod.yml up -d
  ```
  (The API already switches from the log-only sender to real APNs once these are set.)

## 3. App Store Connect
- Create the app **Us.** (choose the `us.elbek.com` bundle id).
- **Subscriptions** → group **"Premium"** → auto-renewable subscription
  **`us.premium.monthly`**, price **€0.99/month**.
- Fill App Privacy (see the labels checklist below) and add the URLs:
  - Privacy: `https://us.islamov.online/privacy`
  - Support: `https://us.islamov.online/support`

## 4. Xcode signing + entitlements (ios/)
In `ios/project.yml`, set your team and add entitlements, then re-run `xcodegen generate`:
```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
targets:
  Us:
    entitlements:
      path: Us/Us.entitlements
      properties:
        com.apple.developer.applesignin: [Default]
        aps-environment: development
        com.apple.security.application-groups: [group.us.elbek.com]
```

## 5. Privacy Nutrition Labels (data collected)
- Contact Info (email), User Content (photos/notes), Identifiers (Apple user id),
  Coarse/Precise Location (**only when the user enables sharing**), Diagnostics.
- Linked to the user; not used for tracking; not sold.

## Order of operations
1–2 unlock push. 3 unlocks the paywall. 4 unlocks Sign in with Apple + widgets on-device.
Ping me once the `.p8` is on the server and I'll flip push live and test on a real device.
