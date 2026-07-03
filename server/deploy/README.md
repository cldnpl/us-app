# Us. Backend — Deployment Runbook

## Current state (deployed ✅)
- Host: **155.138.228.111** (Ubuntu 24.04, nginx reverse proxy, Docker).
- Stack in `/opt/us`: `us-api-1` (API on `127.0.0.1:8090`) + `us-db-1` (Postgres, internal only).
- nginx vhost `usapi.islamov.online` → `127.0.0.1:8090` (`/etc/nginx/sites-available/usapi`).
- SSH: key-based via `~/.ssh/us_deploy_ed25519` (root). Secrets in `/opt/us/.env` (not in git).
- Runs alongside the existing projects (edu-*, olimp-bot, backend-*) without disturbing them.

## Remaining to go fully live (needs the domain owner)
1. **DNS A record:** `usapi.islamov.online` → `155.138.228.111`.
2. **TLS** (after DNS propagates):
   ```bash
   ssh -i ~/.ssh/us_deploy_ed25519 root@155.138.228.111 \
     "certbot --nginx -d usapi.islamov.online --non-interactive --agree-tos -m dev@sharepact.com --redirect"
   ```
3. **Landing custom domain:** add `us.islamov.online` in the Vercel project, then DNS
   **CNAME** `us` → `cname.vercel-dns.com`.
4. **Security:** rotate the shared root password and disable SSH password login
   (key auth is already set up):
   ```bash
   passwd            # set a new root password
   sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl reload ssh
   ```

## Redeploy (after code changes)
```bash
# from server/ on your Mac
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /tmp/api ./cmd/api
scp -i ~/.ssh/us_deploy_ed25519 /tmp/api root@155.138.228.111:/opt/us/api
ssh -i ~/.ssh/us_deploy_ed25519 root@155.138.228.111 \
  "cd /opt/us && docker compose -f docker-compose.prod.yml up -d --build"
```

## Health
```bash
curl -H "Host: usapi.islamov.online" http://155.138.228.111/health   # before DNS
curl https://usapi.islamov.online/health                              # after DNS + TLS
```
