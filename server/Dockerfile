# ---- build stage ----
FROM golang:1.26-alpine AS build
WORKDIR /src
RUN apk add --no-cache git
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# ---- run stage ----
# Runs as root: Railway mounts volumes owned by root, and the media dir
# (MEDIA_DIR=/app/media-data) must be writable for photo uploads.
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=build /out/api /app/api
EXPOSE 8080
ENTRYPOINT ["/app/api"]
