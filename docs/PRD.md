# "Us." — Product, Technical & Delivery Plan

> **Status:** Final draft for approval. Covers the app, backend, real-time features, freemium model, landing page, deployment to your server, branding, and roadmap.
> **App name:** **Us.** (display) · **Date:** 2026-07-03

---

## 1. Context & Vision

**Us.** is a private, two-person app that keeps couples emotionally close — built **first for long-distance couples** (time zones, distance, reunions) and just as warm for couples who live together. The core idea is *ambient presence*: your partner is always one tap — or one glance at a widget — away.

**Design pillars**
1. **Native & HIG-first** — SwiftUI + system components only; feels like an Apple app.
2. **Widget-centric** — home screen and lock screen are primary surfaces.
3. **Two people, private** — no feed, no followers; just the two of you, on your own server.
4. **Completely freemium** — *every* feature exists in the free tier, just **limited**; €0.99/month Premium raises the limits.

---

## 2. Confirmed Decisions

| Area | Decision |
|---|---|
| App name | **Us.** (code module `Us`, display `Us.`) |
| iOS app | **Swift / SwiftUI only**, **iOS 16+** (lock-screen widgets ✅; no in-widget buttons → Miss-You widget deep-links to auto-send) |
| Backend | **Go** (REST + WebSocket), Docker-deployed |
| Auth | **Sign in with Apple + Email/Password** |
| Media | **Your server's disk** (+ thumbnails, per-couple quota, off-box backups) |
| Maps | **Apple MapKit** — partner location in-app + map widget (**opt-in**, no API key) |
| Monetization | **Freemium** — everything free-but-limited; Premium **€0.99 / month** auto-renewable subscription |
| API domain | **`usapi.islamov.online`** → 155.138.228.111 (auto-TLS) |
| Landing page | **Vercel** at **`us.islamov.online`** |
| Backend host | **Your server `155.138.228.111`** (Docker) |
| Scope | **Build all features**, including the "draw/play together" delight set + partner map |

---

## 3. Target Users
- **Long-distance couples (primary):** distance, dual time zones, reunion countdowns, partner location map, async "open when" letters, daily touchpoints.
- **Co-located couples:** shared gallery, anniversaries, games, notes, cute widgets.
- **EU-first** (pricing in €) → **GDPR applies** (§14).

---

## 4. Feature Set (everything is in scope)

### 4.1 Core
| Feature | What it does |
|---|---|
| **Profile creation** | Name, avatar (PhotosPicker), birthday, relationship start date |
| **Pairing with code** | Generate a short code; partner enters it → the two accounts become one **Couple** |
| **Miss You button** | Big tappable button → instant push "❤️ [Name] misses you"; haptic; history |
| **Shared Gallery** | One shared album; photos + video; captions; timeline |
| **Anniversaries & milestones** | Start date + custom milestones; auto countdowns; reminders |
| **Partner location (Apple Maps)** | Opt-in: see partner on an in-app map + a map widget (§4.6) |
| **Widgets** | Home + lock screen (§4.2) |
| **Notifications** | APNs push (§4.3) |
| **Premium** | €0.99/mo subscription raising all limits (§4.4) |

### 4.2 Widgets (first-class)
**Home screen:** ⭐ **Partner Photo (Locket-style)** — latest photo your partner sends straight to your widget · **Miss You / Status** (tap → app auto-sends on iOS 16) · **Countdown** (anniversary/reunion) · **Days Together** · **Distance & Time** (LDR) · **Partner Map** — static MapKit snapshot of your partner's location + distance.
**Lock screen (iOS 16 native):** circular (days/countdown), rectangular (next event / partner status), inline ("❤️ 342 days together").
**Tech:** WidgetKit + **App Group** shared container; **silent push** + `WidgetCenter.reloadTimelines` to refresh. The **Partner Map** widget renders a static `MKMapSnapshotter` image (widgets aren't live/interactive maps).

### 4.3 Notifications catalog
Miss You · new widget photo · new gallery upload · anniversary/reunion approaching · partner mood update · **partner started/arrived (location, opt-in)** · game move/invite · doodle received · daily question ready · streak reminder · "Open When" unlocked. Alert pushes for user-visible events; **silent** pushes drive widget refresh + real-time wakeups.

### 4.4 Freemium model — *everything free, limited; Premium €0.99/mo raises limits*

| Feature | **Free** (present, limited) | **Premium — €0.99/mo** |
|---|---|---|
| Pairing, profile, sign-in | Full | Full |
| Miss You | 10 / day, default styles | Unlimited + custom messages & animations |
| Gallery (photos) | up to 100, standard quality | Unlimited (within quota), HD |
| Video in gallery | 720p, up to 10 clips | 1080p, unlimited (within quota) |
| Photo-to-widget (Locket) | 3 / day | Unlimited |
| Widgets (home + lock) | All types, 1 theme | All + full customization/themes |
| Anniversaries/milestones | 3 | Unlimited |
| Reunion countdown | 1 active | Multiple |
| **Partner location (Apple Maps)** | Last-known / on-demand location on map, opt-in | **Live** continuous sharing + **map widget** + location history/breadcrumbs |
| Draw Together | 3 doodles/day, 6 colors | Unlimited, full palette + brushes |
| Play Together (games) | All games, 1 active match | Unlimited concurrent + bonus packs |
| Thinking-of-You tap | 20 / day | Unlimited |
| "Open When" letters | 3 | Unlimited |
| Notes | 10 stored, no scheduling | Unlimited + scheduled delivery |
| Daily question | Today's | + full archive & bonus packs |
| Streak | Full | + streak freeze / repair |
| Mood / status | Presets | Custom mood + text |
| Voice notes | 15s, 5/day | 2 min, unlimited |
| Distance / timezone / weather | Full | Extra widget styles |
| Themes / alternate app icons | 2 | All |
| **Per-couple storage quota** | **~2 GB** | **~30 GB** |

Nothing is removed from Free — every capability is usable, just capped. Limits are enforced **both client-side (UX) and server-side (source of truth)**.

### 4.5 Delight features (all in scope)
- **Draw Together** — live shared canvas over WebSocket; send finished doodles.
- **Play Together** — Tic-Tac-Toe, Connect Four, Rock-Paper-Scissors, "This or That", Truth or Dare, "How well do you know me?" quiz, 20 Questions, daily trivia.
- **Thinking-of-You tap** — haptic tap/heartbeat to partner's phone.
- **Distance + dual time zones**, **reunion countdown**, **partner weather**, **mood/status**, **battery share (opt-in)**.
- **"Open When…" letters**, **love notes** (scheduled), **daily question**, **streak**, **voice notes**.
- **Memory timeline**, **shared bucket list**, **date/visit planner**, **wishlist**, **shared playlist link**, **reactions/kisses**.

### 4.6 Partner location on Apple Maps (opt-in) ⭐ NEW
- **In-app map:** SwiftUI `Map` (MapKit) centered on your partner with an annotation (avatar pin), distance, and their local time.
- **Map widget:** static `MKMapSnapshotter` image of partner's area + distance (refreshed via silent push).
- **Sharing modes (opt-in, per user):** **Live** (temporary, e.g. "share for 1 hour" or while app open) · **"On my way"** (share until arrival) · **Manual pin** (drop a place, e.g. "at the office"). Continuous background live sharing is a **Premium** perk.
- **Privacy:** always opt-in, **revocable anytime**, with a **pause / "ghost mode"** toggle; precise coordinates stored **only while sharing is active** and **purged when turned off**; requires CoreLocation permission + Info.plist usage strings (§14).

---

## 5. Key User Flows
- **Onboarding:** welcome → Sign in with Apple / Email → profile → "Pair with your partner".
- **Pairing:** A generates code (ShareLink) → B enters it → Couple created. One couple per user; unpair is confirmed and defines media handling (§14).
- **Miss You:** tap → `POST /miss-you` → APNs to partner → logged; optional "Miss you too" reply; rate-limited. Widget path (iOS 16): tap → `usapp://missyou` → auto-send.
- **Photo-to-widget:** pick/capture → upload → silent+alert push → partner's App Group updates → `reloadTimelines` → photo on home screen.
- **Location:** enable sharing (pick mode) → device sends coords → `PUT /location` → partner's map + map widget update via WS/silent push; pause anytime.
- **Draw/Play:** start session → WebSocket streams strokes/moves; offline → push, resume from server-persisted state.

---

## 6. App Structure
Native **TabView**: **Home** (partner card, Miss You, quick actions, mini-map) · **Gallery** · **Together** (draw, games, daily question, notes/"open when") · **Moments** (anniversaries, reunion, timeline, full map) · **Profile/Settings** (pairing, notifications, location sharing, Premium, privacy, delete account). Sign-in + pairing gate the tabs. Deep links: `usapp://missyou`, `usapp://photo`, `usapp://game/{id}`, `usapp://map`.

---

## 7. Native Components & HIG
`NavigationStack`/`TabView` · `List`/`Form`, swipe actions, `ContextMenu` · `PhotosPicker` · `ShareLink` · `SignInWithAppleButton` · StoreKit 2 (custom paywall on iOS 16) · WidgetKit · **MapKit** (`Map`, `MKMapSnapshotter` for the widget) + **CoreLocation** (opt-in) · `UserNotifications` · `.sensoryFeedback` haptics · `.refreshable` · `.sheet`/`.confirmationDialog` · SF Symbols, SF Pro, semantic colors, Dark Mode, Dynamic Type · VoiceOver + String Catalog localization.

---

## 8. Technical Architecture

```
iOS App (SwiftUI, iOS16) ──HTTPS/REST + WSS──▶ Go Backend (your server)
  App target + Widget ext                        chi (REST) · WS hub (games/draw/location)
  App Group cache        ◀──── APNs push ────     Auth (Apple+Email/JWT) · apns2
  MapKit + CoreLocation                           Media on local disk · quotas
  StoreKit 2 ──▶ App Store ◀─ server verify              │
   Caddy / existing proxy (auto-TLS on usapi.islamov.online) ──▶ Go app ──▶ PostgreSQL
```

- **iOS:** SwiftUI + MVVM; `async/await` URLSession; native `URLSessionWebSocketTask`; Core Data/GRDB local cache (SwiftData is iOS17+, excluded); Keychain for tokens; WidgetKit + App Group; MapKit/CoreLocation; `UNUserNotificationCenter`.
- **Go backend:** `chi` router; PostgreSQL via `pgx` + `sqlc`; migrations via `goose`; WebSocket via `coder/websocket` with an in-memory **hub keyed by couple_id** (scaling path: Redis pub/sub); `golang-jwt` + `bcrypt`/`argon2`; Apple identity-token verification; **`sideshow/apns2`** push; media on disk with `disintegration/imaging` thumbnails and auth-checked serving; 12-factor config.
- **Push:** device registers token → server sends alert/silent via apns2 (`.p8`); notification categories for actionable replies.

---

## 9. Data Model (PostgreSQL — key tables)
`users` · `couples` · `couple_members` · `pairing_codes` · `devices` (apns tokens) · `miss_you_events` · `media` (kind, path, thumb, caption, is_widget_photo) · `milestones` · `reunions` · `statuses` (mood, tz, opt-in battery) · `locations` (user_id, lat, lng, accuracy, sharing_mode, expires_at, updated_at) · `notes`/`open_when_letters` · `daily_questions`/`answers` · `streaks` · `game_sessions` (state_json, turn) · `doodles` · `subscriptions`/`entitlements` (product_id, original_transaction_id, status, expires_at) · `storage_usage`. Full DDL at implementation time.

---

## 10. API Surface (REST + WS)
Auth (`/auth/apple`, `/auth/register|login|refresh|logout`) · Profile (`/me`, `/me/avatar`) · Pairing (`/pairing/code`, `/pairing/redeem`, `/couple`) · Miss You (`/miss-you`) · Gallery (`/media`, `/media/:id/file`) · Widget photo (`/widget/photo`) · Milestones/Reunions · Status · **Location** (`/location` PUT/GET, opt-in, mode + expiry) · Notes/Open-When · Daily question · Streak (`/checkin`) · Games (`/games`, moves over WS) · Devices (`/devices`) · **Purchases** (`/purchases/verify`, `/entitlements`) · **App Store webhook** (`/webhooks/appstore`) · **WS** (`/ws`: draw, games, taps, presence, mood, **location**).

---

## 11. Premium & Monetization (StoreKit 2, subscription)
- App Store Connect: **auto-renewable subscription** `us.premium.monthly` (group "Premium"), **€0.99/month**, intro offer optional.
- Client: fetch product, native paywall, purchase; unlock via `Transaction.currentEntitlements`; observe `Transaction.updates`.
- Server: `POST /purchases/verify` validates signed JWS (App Store Server API); **`/webhooks/appstore`** consumes **App Store Server Notifications V2** (renewals/cancellations/refunds/billing-retry) → `entitlements` is the source of truth; freemium limits enforced server-side.

---

## 12. Landing Page (Vercel)
- **Stack:** Next.js (App Router) + Tailwind, deployed via Vercel.
- **Sections:** Hero ("Us." wordmark + tagline *"Two people, one little world."* + app mockup + App Store badge/"Coming soon") · feature highlights (Miss You, photo-to-widget, partner map, draw/play, LDR distance & countdown) · long-distance section · widget showcase · **pricing** (Free vs Premium €0.99/mo) · privacy/trust · footer.
- **Legal pages (Apple-required):** `/privacy`, `/terms`, `/support`.
- **Deploy:** Vercel, custom domain **`us.islamov.online`** (CNAME → Vercel); free `*.vercel.app` for previews.

---

## 13. Deployment & Ops (your server `155.138.228.111`)

**Security first (before anything else):**
1. Create a non-root sudo user; **add an SSH key**; **disable password + root SSH login**; **you then rotate the shared password** you sent (treat it as exposed).
2. `ufw` allow 22/80/443; install `fail2ban`.
3. Secrets (server, DB, JWT, APNs `.p8`, Apple client ids) live in a **git-ignored server `.env`** — never committed, never sent to Vercel or any third party.

**Existing-server check (you run many projects here):** first inspect what already owns ports 80/443. If a reverse proxy (Nginx/Caddy/Traefik/Apache) is already running, **integrate** — add a vhost for `usapi.islamov.online` → the Go app's internal port — rather than binding a second proxy and clashing with your other sites. If nothing owns 80/443, run our own **Caddy** for auto-TLS.
**Runtime:** Docker Compose — `api` (Go, internal port) · `db` (Postgres 16) · `caddy` *(only if no existing proxy)*. Volumes for Postgres data, media dir, certs. DNS: **A record `usapi.islamov.online` → 155.138.228.111**; TLS via Caddy/existing proxy + Let's Encrypt.

**Deploy flow:** build Go image → `docker compose up -d` → migrations (`goose`). Later: GitHub Actions → SSH deploy on push to `main`.
**Durability:** nightly `pg_dump` + media backup (`restic`/`rsync`) **off-box**; restart policy; `/health` checks.

---

## 14. Security & Privacy (GDPR)
TLS everywhere · JWT access + rotating refresh (Keychain) · every couple resource checks membership; media never publicly guessable · rate limiting (auth, Miss You, uploads, location) · **GDPR:** in-app **account deletion** + **data export**, explicit consent for opt-in sharing, documented retention · **unpair semantics** (keep own uploads / delete shared / export-first — confirm) · **Location:** opt-in only, **revocable anytime**, **pause/"ghost mode"**, precise coords stored **only while sharing is active and purged when off**, Info.plist usage strings + When-In-Use/Always prompts · App Store: Privacy Nutrition Labels (incl. location), Sign-in-with-Apple parity, account-deletion requirement — all satisfied.

---

## 15. Branding — Name & Logo
- **Name:** **Us.** — ultra-minimal, intimate, instantly a couple app. Code module `Us`, bundle id suggestion `com.sharepact.us`, URL scheme `usapp://`. (App Store display name "Us." — confirm availability at submission.)
- **Logo prompt (Midjourney/DALL·E/Ideogram):**
  > *Minimalist iOS app icon for a couples app called "Us." Two simple abstract shapes gently merging into one — two hearts overlapping into a single form (alt: two crescent moons forming a circle, or two dots joined by an orbit ring). Flat vector, clean geometry, generous negative space, soft rounded edges. Warm gradient: blush pink → coral → soft peach. Centered on an iOS squircle with a subtle top-down gradient. No text, no letters. Cute, modern, premium, friendly. Flat 2D, crisp, dribbble-quality, App Store icon style. --ar 1:1*
  Palette variant: lavender → periwinkle. Motif variants: continuous line-art heart-knot; two dots + orbit ring.

---

## 16. Project Structure (monorepo)
```
Us/
├── ios/           # Xcode (SwiftUI, iOS16): App target, Widget ext, Shared App-Group models
├── server/        # Go: cmd/api, internal/{http,ws,auth,media,push,location,db,domain}, migrations, Dockerfile, docker-compose.yml
├── landing/       # Next.js + Tailwind (Vercel)
└── docs/PRD.md    # this document, saved into the repo
```

---

## 17. Build Roadmap (all features; deploy early & often)
- **Phase 0 — Foundations & first deploy:** monorepo; **harden server + SSH key + rotate pw**; Go skeleton + Postgres + TLS live → `https://usapi.islamov.online/health`; Xcode SwiftUI project (tabs); landing skeleton live on Vercel.
- **Phase 1 — Accounts & pairing:** Sign in with Apple + email; profile; pairing code; couple; device registration.
- **Phase 2 — Core loop:** Miss You + push; gallery (photo+video); anniversaries/milestones + countdowns; home + lock-screen widgets; notifications.
- **Phase 3 — Signature widget & freemium:** photo-to-widget (Locket); StoreKit 2 subscription + server verify + App Store webhook; freemium limits enforced client+server; paywall.
- **Phase 4 — Delight, real-time & maps:** Draw Together, Play Together games, Thinking-of-You tap, mood/status, streak, daily question, Open When letters, notes/voice notes, distance/timezone/weather, reunion countdown, **partner location map + map widget (Apple Maps)**, memory timeline, playlist.
- **Phase 5 — Polish & launch:** themes/alt icons, accessibility/localization, GDPR export/delete, backups/monitoring, App Store assets (screenshots, privacy labels), landing final + custom domain.

---

## 18. Inputs I'll need from you (as we go)
1. **DNS records** (domain `islamov.online` ✅ provided) — add **A `usapi` → 155.138.228.111** and **CNAME `us` → Vercel**; confirm whether a reverse proxy already runs on the server.
2. **Apple Developer Program** — APNs `.p8`, App ID capabilities (Push, App Groups, Sign in with Apple, In-App Purchase, **Location/Maps**), and the `us.premium.monthly` subscription in App Store Connect.
3. **Vercel account** access (or free `*.vercel.app`).
4. **Email provider** (Postmark/Resend/SES) for verification + password reset.
5. **Weather API key** (optional, weather widget). *(Apple Maps needs no key.)*
6. **Confirm freemium numbers** in §4.4.

---

## 19. Verification Plan
- **Backend:** `docker compose up`; `curl https://usapi.islamov.online/health` (valid TLS); Go unit tests (auth/pairing/limits/location); migrations apply cleanly.
- **App:** iOS Simulator walkthrough (sign-in → pair → Miss You → gallery → map → widget); **two simulators/devices** for pairing, Miss You push, real-time draw/games, live location.
- **Widgets:** add to home + lock screen; confirm refresh on new widget photo + map update.
- **Location:** simulate a moving location; confirm partner map + map widget update and that pausing purges coords.
- **Premium:** StoreKit **sandbox** subscription; verify server entitlement + webhook.
- **Push:** APNs on a **real device** once the Apple push key is configured.
- **Landing:** Vercel preview → production; Lighthouse pass; legal pages reachable.

---

### First actions on approval
1. Save this as `docs/PRD.md` and scaffold the monorepo (§16).
2. **Harden + prep the server** (SSH key, rotate password, Docker; integrate with existing proxy or run Caddy) and bring `https://usapi.islamov.online/health` online.
3. Stand up the **landing page skeleton** on Vercel.
4. Build **Phase 1** end-to-end (sign-in → profile → pairing) and deploy.
