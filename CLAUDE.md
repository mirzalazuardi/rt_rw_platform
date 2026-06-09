# rt_rw_platform

RT/RW governance SaaS: residents request cover letters, manage family cards,
and buy credits via a Telegram Mini App. Officials approve via a web dashboard.

## Big Picture

**Problem:** Indonesian neighborhood (RT/RW) administration is paper-based and
slow. Residents wait days for a cover letter that an official could sign in minutes.

**Users:**
- Residents (family head / member) — Telegram Mini App, initData auth
- Officials (RT, RW, Lurah, Camat) — web dashboard, Rodauth email+password
- Local businesses — ad placement portal

**3 Critical User Flows:**
1. **KK registration & member consent** — family head registers KK, invites
   members; members accept/reject in a single ACID transaction with consent log.
2. **Cover letter lifecycle** — resident submits → RT approves → Go worker
   generates PDF → VIDA Sign signs → signed PDF delivered via Telegram bot.
3. **Credit top-up & transfer** — resident buys a credit package (Midtrans/Xendit),
   transfers credits to another resident with daily limit and 3-day expiry, all ACID.

**Architectural pillars:**
- Ruby (Roda + Rodauth + Sequel + AASM) — main backend, port 9292
- Go (Asynq + wkhtmltopdf) — PDF/signature worker, port 8080
- Redis — Asynq message broker, port 6379
- SQLite WAL (MVP) → PostgreSQL migration path
- Kamal (Docker) — deployment on 2-core / 2 GB VPS

## Configuration

```
DATABASE_URL=sqlite://app.db         # or postgres:// in production
REDIS_URL=redis://localhost:6379/0
TELEGRAM_BOT_TOKEN=
TELEGRAM_BOT_SECRET=                 # HMAC secret for initData validation
VIDA_API_KEY=                        # encrypted at rest in officials table
MIDTRANS_SERVER_KEY=
XENDIT_SECRET_KEY=
SESSION_SECRET=                      # Rodauth cookie signing
SMTP_URL=                            # for Rodauth password reset emails
WORKER_ENQUEUE_URL=http://localhost:8080/enqueue
WORKER_SECRET=                       # shared secret for Ruby→Go HTTP calls
```

Environments: `development`, `test`, `production`.  
Secrets: `.env` locally (never committed), Kamal secrets in production.  
No feature flags in MVP; use plain env var `FEATURE_X=true` if needed.

## Style Guide

Clarity first — code is read more than written. Name things for the reader.

- **SRP** — one class, one reason to change. Extract when a method needs a comment.
- **OCP** — extend via new classes; don't edit stable ones.
- **LSP** — subtypes honour the contract of the parent.
- **ISP** — small, focused interfaces over fat ones.
- **DIP** — depend on abstractions; inject collaborators.

Stack notes:
- Roda: route blocks stay thin; business logic lives in service objects or models.
- Sequel: use dataset methods, never raw SQL in models. Transactions via `DB.transaction`.
- AASM: state transitions fire events only; side-effects go in after-transition hooks.
- Go: one package per concern (`pdf`, `sign`, `notify`); no global state.

Naming: `snake_case` everywhere in Ruby, `camelCase` in Go. DB columns `snake_case`.  
Testing: TDD — write the failing spec first, make it pass, then refactor.  
RSpec for Ruby (`spec/`), standard `testing` package for Go.

## For AI Agents

- Spec files: `openspec/project.md`, `openspec/AGENTS.md`
- Change proposals: `openspec/changes/<kebab-id>/`
- CodeGraph: run `codegraph init -i` after indexing; use `codegraph_*` MCP tools
  for structural questions before grepping.
- Path-scoped instructions: `app/CLAUDE.md` (Ruby), `worker/CLAUDE.md` (Go)
  will be added once those directories exist.
