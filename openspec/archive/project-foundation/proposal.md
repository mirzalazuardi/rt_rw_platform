# Proposal: Project Foundation (Week 1)

**ID:** project-foundation  
**Complexity:** MID  
**Status:** Proposed

---

## Why

Before any feature can be built, the project needs a working skeleton:
Ruby backend that boots, connects to SQLite, handles Rodauth auth, responds
to the Telegram bot `/start` command, and has all 17 database tables migrated.
Without this, no other task has a stable foundation to build on.

## What Changes

- `app/` Ruby project scaffolded: Gemfile, `config.ru`, Roda app class.
- Sequel connected; 17 migration files created (one per PRD table group).
- Rodauth configured for official email/password login with CSRF protection.
- Telegram bot `/start` command wired via Telegem — responds with a welcome message.
- `worker/` Go project scaffolded: `go.mod`, `cmd/worker/main.go`, HTTP server
  with `/enqueue` and `/health` endpoints (stubs, no real processing yet).
- Kamal `config/deploy.yml` and `Dockerfile`s for both services.
- `.env.example` with all required variables.
- RSpec configured; first smoke test: app boots and returns HTTP 200 on `/health`.

## Impact

- Unlocks all Week 2–6 feature work.
- Establishes the DB schema contract all subsequent migrations build on.
- Proves Ruby ↔ Go HTTP handshake works end-to-end (stub level).
- Gives the team a deployable artefact from day 1.
- Any deviation from the PRD schema should be caught here, not in Week 4.
