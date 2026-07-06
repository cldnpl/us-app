#!/usr/bin/env bash
# Builds the linux/amd64 API binary that Dockerfile.prod copies into the image.
# Used by CI (deploy-backend.yml) and available for manual builds.
set -euo pipefail
cd "$(dirname "$0")/.."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o deploy/api ./cmd/api
echo "Built server/deploy/api"
