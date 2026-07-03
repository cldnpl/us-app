.PHONY: run build tidy test up down logs psql

run:
	go run ./cmd/api

build:
	go build -o bin/api ./cmd/api

tidy:
	go mod tidy

test:
	go test ./...

up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f api

psql:
	docker compose exec db psql -U us -d us
