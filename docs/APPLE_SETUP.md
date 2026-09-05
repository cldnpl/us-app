# Apple Developer Setup — Leyla

Everything you need to enable Sign in with Apple, push, and the €2.99/mo subscription.

Bundle IDs:
- App: **`com.claudianapolitano.us`**
- Widget: **`com.claudianapolitano.us.widget`**
- App Group: **`group.com.claudianapolitano.us`**

> The bundle IDs still say `.us` because the app record on the App Store is a
> continuation of the previous "Us." release — same app id, new brand.

## 1. App ID + Capabilities (developer.apple.com → Certificates, IDs & Profiles)

Create/enable an App ID `com.claudianapolitano.us` with:
- ✅ **Push Notifications**
- ✅ **Sign in with Apple**
- ✅ **App Groups** → create `group.com.claudianapolitano.us` (used by the widget)
- ✅ **In-App Purchase** (on by default)
- ✅ **HealthKit** (menstrual-flow read-only)

The **widget** has its own App ID **`com.claudianapolitano.us.widget`** — enable **App Groups** on it too (same `group.com.claudianapolitano.us`) so the app and widget share data. Xcode's automatic signing creates the App ID on first device build; just confirm the App Group capability is checked on both the app and the widget target.

## 2. APNs Auth Key (.p8) — for push

- Keys → **+** → enable **Apple Push Notifications service (APNs)** → download the `.p8` (once only).
- Note the **Key ID** and your **Team ID**.
- Add the key + IDs to Railway env vars for the backend:
  - `APNS_KEY_ID=XXXX`
  - `APNS_TEAM_ID=YYYY`
  - `APNS_KEY_P8` (paste the full .p8 file contents)

(The API switches from the log-only sender to real APNs once these are set.)

## 3. App Store Connect

- App is registered as **Leyla** on the `com.claudianapolitano.us` bundle id.
- **Subscriptions** → group **"Leyla Premium"** → auto-renewable subscription
  **`us.premium.monthly`**, price **€2.99/month**.
  (Product ID keeps the `us.` prefix so existing subscribers keep their entitlement — StoreKit binds by product id, not by display name.)
- Fill App Privacy (see labels checklist below) and add the URLs:
  - Privacy: `https://leyla.app/privacy` (or `https://cldnpl.github.io/us-app/privacy.html` while the domain is being set up)
  - Support: `https://leyla.app/support` (or `https://cldnpl.github.io/us-app/`)

## 4. Xcode signing + entitlements (ios/)

In `ios/project.yml`, set your team and add entitlements, then re-run `xcodegen generate`:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "H4M7KJL5DT"
targets:
  Us:
    entitlements:
      path: Us/Us.entitlements
      properties:
        com.apple.developer.applesignin: [Default]
        aps-environment: development
        com.apple.security.application-groups: [group.com.claudianapolitano.us]
        com.apple.developer.healthkit: true
```

## 5. Privacy Nutrition Labels (data collected)

- Contact Info (email), User Content (photos/notes), Identifiers (Apple user id),
  Coarse/Precise Location (**only when the user enables sharing**),
  Health & Fitness (menstrual cycle, **read-only from Apple Health, not uploaded**),
  Diagnostics.
- Linked to the user; not used for tracking; not sold.

## Order of operations

1–2 unlock push. 3 unlocks the paywall. 4 unlocks Sign in with Apple + widgets + HealthKit on-device.
