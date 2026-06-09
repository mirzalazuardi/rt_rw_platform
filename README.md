# rt_rw_platform

RT/RW governance SaaS — residents request cover letters and manage family cards
via a Telegram Mini App; officials sign and approve via a web dashboard.

## Prerequisites

- Ruby 3.3.x (`rbenv` or `rvm`)
- Go 1.22.x
- Redis 7.x
- SQLite 3.45+
- wkhtmltopdf 0.12.6
- Docker + Kamal (for deployment)

## Setup

```bash
cp .env.example .env          # fill in your secrets

# Ruby backend
cd app
bundle install
bundle exec sequel -m db/migrations sqlite://app.db   # run migrations

# Go worker
cd ../worker
go mod download
```

## Run (development)

```bash
# Terminal 1 — Ruby backend
cd app && bundle exec rackup -p 9292

# Terminal 2 — Go worker
cd worker && go run cmd/worker/main.go

# Terminal 3 — Redis (if not running as a service)
redis-server
```

## Run Tests

```bash
# Ruby
cd app && bundle exec rspec

# Go
cd worker && go test ./...
```

## Deploy

```bash
# First deploy
kamal setup

# Subsequent deploys
kamal deploy
```

## Architecture

```
Telegram ──► Ruby/Roda (9292) ──► SQLite
                  │
                  ▼ HTTP POST /enqueue
              Go/Asynq (8080) ──► Redis (6379)
                  │
                  ▼ HTTP POST /webhooks/vida_callback
              VIDA Sign API ──► signed PDF ──► Telegram bot
```

See `openspec/project.md` for full stack details and `openspec/changes/` for
active development proposals.
