# Spec: Ruby Project Skeleton

**Capability:** Bootable Ruby backend with Sequel, Rodauth, Telegram bot webhook,
and all 17 database tables migrated.

---

## Constraints (RFC 2119)

- The application MUST boot from `bundle exec rackup -p 9292` without errors.
- `GET /health` MUST return HTTP 200 with no authentication required.
- All 17 tables listed in `PRD_RT_RW_Platform_v3.1_EN.md` Section 5 MUST exist
  after running all migrations.
- Official authentication MUST use Rodauth; residents MUST NOT use Rodauth.
- `POST /webhook/telegram` MUST reject requests missing a valid
  `X-Telegram-Bot-Api-Secret-Token` header with HTTP 403.
- Financial tables (`credits`, `credit_transfers`) MUST use INTEGER for all
  monetary amounts (no FLOAT or DECIMAL).
- The `families` table MUST NOT be created before the `residents` table
  (foreign key dependency order).

---

#### Scenario: App health check

**Given** the Ruby backend is running  
**When** a client sends `GET /health`  
**Then** the response status is 200  
**And** the response body contains `"OK"`

---

#### Scenario: Official accesses dashboard without login

**Given** no session cookie is present  
**When** a client sends `GET /dashboard`  
**Then** the response status is 302  
**And** the `Location` header points to `/login`

---

#### Scenario: Official logs in with valid credentials

**Given** an official account exists with email `rt1@example.com` and a known password  
**When** the client POSTs valid credentials to `/login`  
**Then** the response status is 302  
**And** a session cookie is set  
**And** subsequent `GET /dashboard` returns 200

---

#### Scenario: Telegram bot receives /start command with valid secret

**Given** `ENV['TELEGRAM_BOT_SECRET']` is set to `"test-secret"`  
**When** the client POSTs a `/start` update to `/webhook/telegram`  
  with header `X-Telegram-Bot-Api-Secret-Token: test-secret`  
**Then** the response status is 200  
**And** the response body is non-empty

---

#### Scenario: Telegram bot rejects request with wrong secret

**Given** `ENV['TELEGRAM_BOT_SECRET']` is set to `"test-secret"`  
**When** the client POSTs to `/webhook/telegram`  
  with header `X-Telegram-Bot-Api-Secret-Token: wrong-secret`  
**Then** the response status is 403

---

#### Scenario: All database tables exist after migrations

**Given** migrations have been run against a fresh SQLite file  
**When** the database schema is inspected  
**Then** the following tables exist:  
  `regions`, `accounts`, `officials`, `residents`, `families`,
  `family_invitations`, `consent_logs`, `letter_requests`,
  `digital_signatures`, `credits`, `credit_transactions`,
  `credit_usages`, `credit_transfers`, `ads`, `ad_impressions`,
  `announcements`, `numbering_configs`, `numbering_overrides`

---

#### Scenario: Go worker health check

**Given** the Go worker is running on port 8080  
**When** a client sends `GET /health`  
**Then** the response status is 200  
**And** the response body is `{"status":"ok"}`

---

#### Scenario: Go worker enqueue stub accepts a job

**Given** the Go worker is running  
**When** a client POSTs `{"job_type":"pdf","payload":{}}` to `POST /enqueue`  
**Then** the response status is 200  
**And** the response body contains `"queued"`
