# Tasks: project-foundation

Complexity: MID — each task is one atomic slice, independently runnable and
verifiable. Complete in order; each task assumes the previous ones are done.

---

## TASK-001 — Create .gitignore and .env.example

**What:** Add `.gitignore` (ignore `.env`, `*.db`, `tmp/`, `log/`, Go binaries,
`public/uploads/`) and `.env.example` with every variable from the Configuration
section of `CLAUDE.md` (empty values, with inline comments).

**Verify:** `git status` shows `.env` is untracked/ignored. `.env.example` is committed.

---

## TASK-002 — Scaffold Ruby app directory

**What:** Create `app/` with:
- `Gemfile` pinning `ruby '3.3'`, gems: `roda`, `sequel`, `rodauth`, `aasm`,
  `telegrem` (or `telegram-bot-ruby` if telegrem unavailable), `dotenv`,
  `bcrypt`, `sqlite3`, `puma`, `rack-test` (test group), `rspec` (test group),
  `database_cleaner-sequel` (test group).
- `config.ru` — requires the app, runs `App`.
- `app/app.rb` — minimal `App < Roda` class that returns `"OK"` on `GET /health`.

**Verify:** `cd app && bundle install` exits 0. `bundle exec rackup -p 9292` boots
without errors.

---

## TASK-003 — Configure RSpec

**What:** Create `app/spec/spec_helper.rb`:
- Loads `dotenv` from `.env.test` (create a minimal `.env.test` too).
- Sets `DATABASE_URL=sqlite://test.db`.
- Configures `DatabaseCleaner` with truncation strategy.
- Requires `rack/test` and the main app.

Create `app/spec/app_spec.rb` with one test: `GET /health` returns status 200.

**Verify:** `cd app && bundle exec rspec` — 1 example, 0 failures.

---

## TASK-004 — Configure Sequel database connection

**What:** Create `app/config/database.rb`:
- `DB = Sequel.connect(ENV.fetch('DATABASE_URL', 'sqlite://app.db'))`.
- Enable WAL: `DB.run("PRAGMA journal_mode=WAL")` for SQLite.
- Enable busy timeout: `DB.run("PRAGMA busy_timeout=5000")`.

Require `config/database.rb` from `app.rb` before any model load.

**Verify:** `ruby -e "require_relative 'app/config/database'; puts DB.test_connection"`
exits 0 and prints `true`.

---

## TASK-005 — Create Sequel migration: regions + officials + accounts stub

**What:** Create `app/db/migrations/001_create_regions_officials.rb`:
- Table `regions` (id, level, parent_id, code, name, created_at) per PRD schema.
- Table `accounts` (Rodauth-managed: id, email, password_hash, status_id,
  created_at) — minimal columns; Rodauth adds the rest via its own migration helper.
- Table `officials` (id, account_id FK, region_id FK, role, name,
  telegram_user_id, vida_api_key_encrypted, vida_private_key_encrypted, created_at).
- Add indexes: `regions(code)`, `officials(region_id, role) UNIQUE`.

**Verify:** `cd app && bundle exec sequel -m db/migrations sqlite://app.db` runs
with no errors. `sqlite3 app.db ".tables"` shows `regions officials accounts`.

---

## TASK-006 — Create Sequel migration: families + residents + invitations + consent

**What:** Create `app/db/migrations/002_create_families_residents.rb`:
- Tables (in dependency order): `residents`, `families`, `family_invitations`,
  `consent_logs` per PRD schema.
- Add all indexes from PRD: `residents(region_id)`, `residents(family_id)`,
  `families(no_kk)`, `family_invitations(token)`.

**Verify:** Run migrations; `sqlite3 app.db ".tables"` includes the four new tables.

---

## TASK-007 — Create Sequel migration: letter_requests + digital_signatures

**What:** Create `app/db/migrations/003_create_letters.rb`:
- Tables: `letter_requests`, `digital_signatures` per PRD schema.
- Indexes: `letter_requests(applicant_resident_id)`, `letter_requests(status)`.

**Verify:** Run migrations; tables exist in `app.db`.

---

## TASK-008 — Create Sequel migration: credits + transactions + transfers

**What:** Create `app/db/migrations/004_create_credits.rb`:
- Tables: `credits`, `credit_transactions`, `credit_usages`, `credit_transfers`
  per PRD schema.
- Indexes: `credits(resident_id)`, `credit_transfers(from_resident_id)`,
  `credit_transfers(to_resident_id)`.

**Verify:** Run migrations; tables exist.

---

## TASK-009 — Create Sequel migration: ads + announcements + numbering

**What:** Create `app/db/migrations/005_create_ads_announcements_numbering.rb`:
- Tables: `ads`, `ad_impressions`, `announcements`, `numbering_configs`,
  `numbering_overrides` per PRD schema.

**Verify:** Run migrations; all 17 PRD tables now exist in `app.db`.

---

## TASK-010 — Define Sequel models (stubs)

**What:** Create one file per model in `app/models/`:
`region.rb`, `official.rb`, `family.rb`, `resident.rb`, `family_invitation.rb`,
`consent_log.rb`, `letter_request.rb`, `digital_signature.rb`, `credit.rb`,
`credit_transaction.rb`, `credit_usage.rb`, `credit_transfer.rb`, `ad.rb`,
`ad_impression.rb`, `announcement.rb`, `numbering_config.rb`,
`numbering_override.rb`.

Each model: inherits `Sequel::Model`, declares `many_to_one` / `one_to_many`
associations per the PRD schema. No business logic yet.

Write one RSpec model spec for `Resident`: verify it can be instantiated and
`.table_name` returns `:residents`.

**Verify:** `bundle exec rspec spec/models/resident_spec.rb` — green.

---

## TASK-011 — Configure Rodauth for official authentication

**What:** Create `app/config/rodauth.rb`:
- Enable features: `:login`, `:logout`, `:create_account`, `:reset_password`.
- `account_password_hash_column :password_hash`.
- `email_from "noreply@rt-rw.local"`.

Wire Rodauth into `App < Roda` (plugin `:rodauth`). Add a protected route:
`GET /dashboard` that calls `rodauth.require_authentication` and returns
`"Dashboard OK"`. Unprotected: `GET /health`.

Write two RSpec route specs:
1. `GET /dashboard` without session → redirects to `/login`.
2. `GET /health` → 200 OK.

**Verify:** Both specs green.

---

## TASK-012 — Wire Telegram bot /start command

**What:** Create `app/routes/bot.rb` handling `POST /webhook/telegram`:
- Validates `X-Telegram-Bot-Api-Secret-Token` header against `ENV['TELEGRAM_BOT_SECRET']`.
- Parses the incoming update JSON.
- Responds to `/start` with `"Selamat datang di Sistem RT/RW! 🏠"`.
- Returns HTTP 200 for all other updates (ignore for now).

Write one RSpec spec: POST `/webhook/telegram` with a valid secret and a
`/start` message → returns 200 and a non-empty response body.

**Verify:** Spec green.

---

## TASK-013 — Scaffold Go worker

**What:** Create `worker/`:
- `go.mod` with module `rt_rw_platform/worker`, Go 1.22, dependencies:
  `github.com/hibiken/asynq`, `github.com/redis/go-redis/v9`.
- `cmd/worker/main.go`: HTTP server on `:8080` with:
  - `POST /enqueue` — reads JSON body, returns `{"status":"queued"}` (stub).
  - `GET /health` — returns `{"status":"ok"}`.
- `worker_test.go`: test that `GET /health` returns 200 and `{"status":"ok"}`.

**Verify:** `cd worker && go test ./...` — green. `go run cmd/worker/main.go`
boots and `curl localhost:8080/health` returns `{"status":"ok"}`.

---

## TASK-014 — Add Kamal config and Dockerfiles

**What:**
- `Dockerfile.app` (Ruby): multi-stage, installs gems, exposes 9292.
- `Dockerfile.worker` (Go): multi-stage, builds binary, exposes 8080.
- `config/deploy.yml`: Kamal 2.x config with two services (`app`, `worker`),
  Redis accessory, env var injection from `.env`.

No actual deploy in this task — config only.

**Verify:** `kamal config` parses without errors (requires Kamal installed locally).

---

## TASK-015 — Run full test suite and confirm green baseline

**What:**
- `cd app && bundle exec rspec` — all specs green, 0 failures.
- `cd worker && go test ./...` — all tests green.
- `bundle exec rspec --format documentation` output saved to `tmp/baseline.txt`
  (gitignored) for reference.

**Verify:** Both commands exit 0. Document any skipped tests with a `# TODO` comment.

---
