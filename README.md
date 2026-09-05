# Leyla 💞

A private, two-person app that keeps couples close — built first for **long-distance** relationships and just as warm for couples who live together.

> Ambient presence: your partner is always one tap — or one glance at a widget — away.

Previously shipped as **Us.** — same app, same code, new name and softer look.

## Monorepo layout

| Path | What |
|---|---|
| [`ios/`](ios/) | SwiftUI app (iOS 16+) + WidgetKit extension. Swift only, HIG-first. |
| [`server/`](server/) | Go backend — REST + WebSocket, PostgreSQL, APNs push. Deployed on Railway. |
| [`landing/`](landing/) | Next.js marketing site (deploys to Vercel). |
| [`docs/`](docs/) | Product & technical docs. Start with [`docs/PRD.md`](docs/PRD.md). |

## Key facts

- **App name:** Leyla · **Platform:** iOS 16+ · **Language:** Swift/SwiftUI
- **Bundle ID:** `com.claudianapolitano.us` (unchanged from the Us. era so the App Store record stays continuous)
- **Backend:** Go · Postgres · media on a Railway volume · API at `https://us-app-production-9aa4.up.railway.app`
- **Auth:** Sign in with Apple + Email/Password
- **Monetization:** freemium — everything free-but-limited; Leyla Premium **€2.99/month**
- **Maps:** Apple MapKit (opt-in partner location)
- **Health:** read-only HealthKit integration for menstrual cycle + pregnancy tracking

## Quick start (backend)

```bash
cd server
cp .env.example .env      # fill in secrets
docker compose up --build # api on :8080, postgres on :5432
curl http://localhost:8080/health
```

## Quick start (iOS)

```bash
cd ios
xcodegen generate         # regenerates Us.xcodeproj from project.yml
open Us.xcodeproj
```

Then Product ▸ Run in Xcode. The Xcode project and folders are still named `Us` / `UsWidget` — only the display name and in-app branding changed.

See [`docs/PRD.md`](docs/PRD.md) for the full plan, feature set, and roadmap.
