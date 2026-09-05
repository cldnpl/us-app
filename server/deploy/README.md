# Leyla Backend — Deployment

The backend runs on **Railway** and auto-deploys from `main` on every push
(GitHub Actions → Railway).

- **Production URL:** `https://us-app-production-9aa4.up.railway.app`
- **Health check:** `GET /health`
- **Migrations:** goose migrations under `server/internal/db/migrations` run
  automatically on server startup — no manual step.

## Local development

```bash
cd server
cp .env.example .env      # fill in secrets
docker compose up --build # api on :8080, postgres on :5432
curl http://localhost:8080/health
```

## Redeploy

Just push to `main`. Railway rebuilds and rolls out. No SSH, no scp, no
docker-compose-prod dance.

## Legacy note

An older iteration of this backend ran on a self-managed Vultr host
(`usapi.islamov.online`, IP `155.138.228.111`). That host is dead and the
domain is no longer live. The Railway deployment is now the single source
of truth.
