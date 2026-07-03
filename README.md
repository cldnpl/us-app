# Us. 💞

A private, two-person app that keeps couples close — built first for **long-distance** relationships and just as warm for couples who live together.

> Ambient presence: your partner is always one tap — or one glance at a widget — away.

## Monorepo layout

| Path | What |
|---|---|
| [`ios/`](ios/) | SwiftUI app (iOS 16+) + WidgetKit extension. Swift only, HIG-first. |
| [`server/`](server/) | Go backend — REST + WebSocket, PostgreSQL, APNs push. Docker-deployed. |
| [`landing/`](landing/) | Next.js marketing site (deploys to Vercel at `us.islamov.online`). |
| [`docs/`](docs/) | Product & technical docs. Start with [`docs/PRD.md`](docs/PRD.md). |

## Key facts

- **App name:** Us. · **Platform:** iOS 16+ · **Language:** Swift/SwiftUI
- **Backend:** Go · Postgres · media on server disk · API at `https://usapi.islamov.online`
- **Auth:** Sign in with Apple + Email/Password
- **Monetization:** freemium — everything free-but-limited; Premium **€0.99/month**
- **Maps:** Apple MapKit (opt-in partner location)

## Quick start (backend)

```bash
cd server
cp .env.example .env      # fill in secrets
docker compose up --build # api on :8080, postgres on :5432
curl http://localhost:8080/health
```

See [`docs/PRD.md`](docs/PRD.md) for the full plan, feature set, and roadmap.
