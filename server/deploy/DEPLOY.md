# Backend deploy

The API auto-deploys to `usapi.islamov.online` on every push to `main` that
touches `server/**`, via `.github/workflows/deploy-backend.yml`.

CI cross-compiles the linux/amd64 binary (the server is too small to compile),
ships it plus `Dockerfile.prod` and `docker-compose.prod.yml` to the server, and
runs `docker compose ... up --build -d`. Database migrations are embedded in the
binary (`//go:embed migrations/*.sql`) and apply themselves on boot via goose —
no manual migration step.

## One-time setup (required before auto-deploy works)

Add these in GitHub → **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `DEPLOY_HOST` | server hostname or IP of the box running the prod stack |
| `DEPLOY_USER` | ssh user on that box |
| `DEPLOY_SSH_KEY` | private ssh key authorized for `DEPLOY_USER` (a dedicated deploy key) |
| `DEPLOY_PATH` | absolute path of the prod deploy dir — the folder that already holds `.env` (with `POSTGRES_PASSWORD`, `JWT_SECRET`, `APNS_*`) and `AuthKey.p8` |

The deploy only overwrites `api`, `Dockerfile.prod`, and `docker-compose.prod.yml`
in `DEPLOY_PATH`; it never touches `.env` or `AuthKey.p8`.

Once the secrets exist, every backend push deploys itself — no commands, no SSH.

## Verify a deploy

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://usapi.islamov.online/v1/cycle
# 401 = deployed (route exists, needs auth). 404 = old build still running.
```

## Manual deploy (fallback, if ever needed)

```bash
server/deploy/build-binary.sh                     # builds server/deploy/api
# copy server/deploy/{api,Dockerfile.prod,docker-compose.prod.yml} to DEPLOY_PATH
cd "$DEPLOY_PATH" && docker compose -f docker-compose.prod.yml up --build -d
```
