# PRD Final – RT/RW Management Information System (Telegram Mini App)

**Version:** 3.1  
**Date:** 2026-06-10  
**Status:** Final – Ready for Implementation  

---

## 1. Executive Summary

**Product:** A digital platform for RT/RW, sub-district (kelurahan), and district (kecamatan) levels that enables residents to request cover letters, purchase premium credits, transfer credits, and receive announcements via a Telegram Mini App.

**Business Model:**
- **Free forever** for all officials (RT, RW, Lurah, Camat).
- **Profit sources:**
  1. Premium credit sales to residents (digital stamp duty, physical letter delivery, document printing).
  2. Paid advertisements from local businesses.
  3. Anonymized aggregate data reports (Phase 2).

**Development Principles:**
- Code prioritizes **clarity** and SOLID (Sandi Metz).
- Every feature must include **RSpec** (Ruby) and **unit tests** (Go).
- **State machine** for letters using the `aasm` gem in Ruby.
- **Background jobs & PDF generation** using **Go + Asynq** + Redis.
- **Database:** SQLite (WAL) for MVP, migration-ready to PostgreSQL.
- **All financial transactions comply with ACID**.
- **Family Account:** One Telegram account represents one Family Card (KK). The family head registers the KK, invites members; members must give consent.
- **Official authentication** uses **Rodauth** (login, session, password reset).
- **ORM** uses **Sequel** (migrations, models, validations).

---

## 2. Target Users & Personas

| User | Role | Access | Authentication | Monetization |
|------|------|--------|----------------|--------------|
| Resident (Family Head) | Register KK, invite members, request letters for self or others | Mini App | Telegram initData + KK verification | Buys credits |
| Resident (Family Member) | Request letters for self (after accepting invitation & consent) | Mini App | Telegram initData + invitation consent | Buys credits |
| RT Chair | Approve letters, manage residents, send announcements, approve ads | Web Dashboard + Bot | Rodauth (email + password) | Free |
| RW Secretary | Manage multi-RT, reports | Web Dashboard | Rodauth | Free |
| Lurah/Village Head | Approve letters (Phase 2) | Web Dashboard | Rodauth | Free |
| Camat/District Head | Approve letters (Phase 2) | Web Dashboard | Rodauth | Free |
| Local Business | Place ads, view reports | Separate Web | Email + password | Paid |

**Initial assumptions:** 1 RW with 5 RTs (150 KKs). Each KK averages 4 members. Only the family head and invited adult members will have a bound Telegram account.

---

## 3. MVP Features (Priority)

### 3.1 Family Account Management

#### 3.1.1 Family Card Registration (Family Head)
- Family head opens the Mini App, selects "Register Family".
- Enters **KK Number** and **Family Head NIK**.
- System verifies data (format validation, prevent KK duplication, optional integration with initial data from CSV or Dukcapil API).
- If valid, the system creates:
  - One `families` record (no_kk, head_resident_id).
  - One `residents` record for the family head with `role_in_family = 'head'`, `telegram_chat_id` filled from the logged-in account.
- The family head is immediately bound and can use the application.

#### 3.1.2 Member Management & Invitations
- Once the KK is registered, the system automatically creates placeholder `residents` for each family member (data can be imported from a CSV uploaded by the family head, or from an initial file). Each placeholder has `registration_pending = true` and `telegram_chat_id = NULL`.
- The family head views the list of unbound members. For each member, they can send an **invitation via Telegram** (if phone number/username is available) or share an invitation link.
- System creates a record in `family_invitations` with a unique token, valid for 7 days.

#### 3.1.3 Family Member Consent
- Member receives the invitation link (e.g., `https://t.me/YourBot?start=invite_<token>`).
- Opens the Mini App; the system displays family information and member data (name, NIK, address — partially hidden for privacy).
- Member presses **Agree** or **Reject**.
- If **Agreed**:
  - In a single ACID transaction: update the relevant `residents` with `telegram_chat_id` (from the logged-in account), `family_id`, `role_in_family = 'member'`, `registration_pending = false`.
  - Update `family_invitations.status = 'accepted'`.
  - Log consent in `consent_logs` (timestamp, IP, user agent).
  - The member can now request letters for themselves.
- If **Rejected**:
  - Update `family_invitations.status = 'rejected'`.
  - No data changes.

#### 3.1.4 Permissions & Limitations
- **Family head** can request letters for **themselves** and for **other family members** (on their behalf).
- **Family members** can only request letters for **themselves**.
- To request a letter on behalf of another member, the family head must select the applicant's name from the family list.
- All requested letters will show the actual applicant's NIK and the KK number as family identity.
- The **full delegation** feature (member representing another member) is not included in the MVP but can be added in Phase 2 as "digital power of attorney".

### 3.2 Cover Letter Requests (State Machine with `aasm`)
**Letter types:** `ktp`, `kk`, `domisili`.

**State flow:**
```
draft → pending_rt → pending_rw → pending_lurah → pending_camat → completed
↓ (reject) → rejected
```

- Resident (family head or member) fills out form: selects **applicant** (if family head, can choose self or another member; if member, only self).
- Submit → status `pending_rt`, RT notification.
- RT approves → system invokes Go worker to generate PDF, VIDA Sign digital signature, save PDF, update status.
- Signed letter is sent to the applicant (the applicant's Telegram account).

### 3.3 Digital Signature & Stamp Duty (VIDA Sign)
- **Officials:** 10 free digital signatures initially.
- **Residents** purchase credits for digital stamp duty, additional signatures, physical delivery, document printing.

### 3.4 Custom Document Numbering
- Each official can set a letter number format per letter type.
- Placeholders: `{prefix}`, `{seq}`, `{seq:04d}`, `{year}`, `{month}`, `{type}`.
- Starting number overrides are recorded in the `numbering_overrides` table.

### 3.5 Resident Credits & Credit Transfers
- Residents purchase credit packages (Starter, Family, Pro) via Midtrans/Xendit.
- Credits used for digital stamp duty, additional signatures, physical letter delivery, document printing.
- Credit transfers between residents with recipient confirmation, daily limit, and 3-day expiry.
- **Credits are tied to individual residents** (not per KK). Each family member has their own balance.

### 3.6 Ads & Announcements
- Local businesses place ads (simple CPM/CPC) with RT approval.
- RT/RW send announcements to residents via the bot.

---

## 4. Technical Architecture

### 4.1 Components and Languages

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Main backend** | Ruby + Roda | Familiar, lightweight, high clarity. |
| **Official Auth** | **Rodauth** | Full-featured (login, session, password hash, CSRF), easy integration with Roda. |
| **Database ORM** | **Sequel** | Flexible, good performance, supports SQLite & PostgreSQL, structured migrations. |
| **Background jobs & PDF** | Go + Asynq | Memory efficient (~30-50MB), easy to learn. |
| **Message broker** | Redis | Supported by Asynq, lightweight (~200MB). |
| **Database** | SQLite (WAL) → PostgreSQL | SQLite is cheap, easy migration path. |
| **State machine** | `aasm` gem | Centralized letter status logic. |
| **Digital signature** | VIDA Sign API | Legally valid, 10 free initially. |
| **Mini App frontend** | HTML + Vanilla JS | Lightweight, WebView compatible. |
| **Telegram Bot** | Telegem (Ruby) | Lightweight, Roda integration. |
| **PDF generation** | Go + wkhtmltopdf | HTML to PDF, template-friendly. |
| **Payment gateway** | Midtrans / Xendit | Popular in Indonesia. |
| **Deployment** | VPS 2GB (2 core) | Minimal cost ($4.2/month). |

### 4.2 Authentication with Rodauth

- **For Officials (RT, RW, Lurah, Camat):**  
  Uses Rodauth with features:
  - Login via email/username and password.
  - Cookie-based sessions (with CSRF protection).
  - Password hashing (bcrypt/Argon2).
  - Forgot password (reset via email).
  - Optional: 2FA (Phase 2).
  - Each official has an account in the `accounts` table (managed by Rodauth), then linked to the `officials` table (specific data like region_id, role, VIDA credentials).

- **For Residents (Mini App):**  
  Authentication **still uses Telegram `initData`** (without Rodauth). Residents do not need password login. Every request to the backend API (other than public endpoints) must include `initData` validated server-side.

- **Official Dashboard:**  
  Built with Roda + Rodauth. After login, officials access dashboard pages (HTML) and session-protected API endpoints.

- **API for Mini App:**  
  Protected by `initData` validation (not session). Can use a custom Roda middleware.

### 4.3 Database ORM: Sequel

- **Migrations:** Using `sequel-migrate`. All schema changes managed through migrations.
- **Models:** Each table has a Sequel model. Relationships, validations, and hooks defined in models.
- **Connection:** `Sequel::Database` configuration in `config/database.rb`.
- **ACID Transactions:** Sequel supports `DB.transaction` with isolation levels. For SQLite, use `DB.transaction(immediate: true)` to lock the database.

**Example models:**

```ruby
# models/resident.rb
class Resident < Sequel::Model
  many_to_one :family
  one_to_many :letter_requests, key: :applicant_resident_id
end

# models/letter_request.rb
class LetterRequest < Sequel::Model
  include AASM
  many_to_one :applicant_resident, class: 'Resident'
  aasm column: :status do
    state :draft, initial: true
    state :pending_rt
    # ...
  end
end
```

### 4.4 Rodauth Integration with Sequel
Rodauth automatically uses the same Sequel connection. Example configuration:

```ruby
# roda_app.rb
require 'roda'
require 'sequel'
require 'rodauth'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://app.db')

class App < Roda
  plugin :rodauth do
    enable :login, :logout, :create_account, :reset_password
    account_password_hash_column :password_hash
  end

  route do |r|
    r.rodauth          # handles /login, /logout, etc.

    r.on 'dashboard' do
      rodauth.require_authentication
      # ...
    end

    r.on 'api' do
      # initData validation middleware
    end
  end
end
```

### 4.5 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        VPS 2GB                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Ruby       │    │   Redis      │    │   Go Worker  │  │
│  │   (Roda)     │◄──►│  (broker)    │◄──►│  (Asynq)     │  │
│  │   :9292      │    │   :6379      │    │   :8080      │  │
│  └──────┬───────┘    └──────────────┘    └──────┬───────┘  │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌──────────────┐                        ┌──────────────┐  │
│  │   SQLite     │                        │  wkhtmltopdf │  │
│  │  (database)  │                        │  (binary)    │  │
│  └──────────────┘                        └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
        │                                                   │
        ▼                                                   ▼
   Telegram API                                        VIDA Sign API
   (bot, Mini App)                                     (signatures)
```

### 4.6 Ruby ↔ Go Communication
1. Ruby (Roda) receives an approval request from RT.
2. Ruby generates the document number, creates the HTML letter template, saves it temporarily.
3. Ruby sends the job to the Go worker via HTTP POST /enqueue (JSON payload).
4. Go worker receives it, enqueues to Asynq (Redis).
5. Asynq worker processes:
   - Generate PDF from HTML (wkhtmltopdf).
   - Send to VIDA Sign API (inline sign).
   - Save the signed PDF.
6. Call HTTP callback to Ruby (/webhooks/vida_callback).
7. Ruby receives the callback, updates letter status, sends PDF to the resident via bot.

**Go worker endpoints:**
- `POST /enqueue` → receives jobs.
- `GET /health` → health check.

**Ruby webhook:**
- `POST /webhooks/vida_callback` → receives notifications from Go.

---

## 5. Database Schema (SQLite Final)

All tables managed via Sequel migrations. Full DDL below (for reference):

```sql
-- 1. Regions
CREATE TABLE regions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  level TEXT NOT NULL,
  parent_id INTEGER,
  code TEXT UNIQUE NOT NULL,
  name TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_id) REFERENCES regions(id)
);

-- 2. Officials – linked to Rodauth accounts
CREATE TABLE officials (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL,   -- from accounts table (rodauth)
  region_id INTEGER NOT NULL,
  role TEXT NOT NULL,
  name TEXT NOT NULL,
  telegram_user_id INTEGER,
  vida_api_key_encrypted TEXT,
  vida_private_key_encrypted TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (region_id) REFERENCES regions(id),
  FOREIGN KEY (account_id) REFERENCES accounts(id),
  UNIQUE(region_id, role)
);

-- 3. Families (KK)
CREATE TABLE families (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  no_kk TEXT UNIQUE NOT NULL,
  head_resident_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (head_resident_id) REFERENCES residents(id)
);

-- 4. Residents
CREATE TABLE residents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nik TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  telegram_chat_id INTEGER,
  region_id INTEGER NOT NULL,
  address TEXT,
  family_id INTEGER,
  role_in_family TEXT DEFAULT 'member',
  registration_pending BOOLEAN DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (region_id) REFERENCES regions(id),
  FOREIGN KEY (family_id) REFERENCES families(id)
);

-- 5. Family invitations
CREATE TABLE family_invitations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  family_id INTEGER NOT NULL,
  resident_id INTEGER NOT NULL,
  invited_by_resident_id INTEGER NOT NULL,
  token TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'pending',
  expires_at DATETIME DEFAULT (DATETIME('now', '+7 days')),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (family_id) REFERENCES families(id),
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  FOREIGN KEY (invited_by_resident_id) REFERENCES residents(id)
);

-- 6. Consent logs
CREATE TABLE consent_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  ip TEXT,
  user_agent TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 7. Letter requests
CREATE TABLE letter_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  requested_by_resident_id INTEGER NOT NULL,
  applicant_resident_id INTEGER NOT NULL,
  letter_type TEXT NOT NULL,
  reason TEXT,
  status TEXT DEFAULT 'draft',
  pdf_path TEXT,
  document_number TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (requested_by_resident_id) REFERENCES residents(id),
  FOREIGN KEY (applicant_resident_id) REFERENCES residents(id)
);

-- 8. Digital signatures
CREATE TABLE digital_signatures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  letter_request_id INTEGER NOT NULL,
  official_id INTEGER NOT NULL,
  vida_sign_request_id TEXT,
  signed_at DATETIME,
  FOREIGN KEY (letter_request_id) REFERENCES letter_requests(id),
  FOREIGN KEY (official_id) REFERENCES officials(id)
);

-- 9. Credits
CREATE TABLE credits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  balance INTEGER DEFAULT 0,
  updated_at DATETIME,
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 10. Top-up transactions
CREATE TABLE credit_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  amount_real_currency INTEGER,
  payment_gateway_id TEXT,
  status TEXT DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 11. Credit usage
CREATE TABLE credit_usages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  letter_request_id INTEGER,
  service_type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  used_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  FOREIGN KEY (letter_request_id) REFERENCES letter_requests(id)
);

-- 12. Credit transfers
CREATE TABLE credit_transfers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_resident_id INTEGER NOT NULL,
  to_resident_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  message TEXT,
  status TEXT DEFAULT 'pending',
  expires_at DATETIME DEFAULT (DATETIME('now', '+3 days')),
  confirmed_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (from_resident_id) REFERENCES residents(id),
  FOREIGN KEY (to_resident_id) REFERENCES residents(id)
);

-- 13. Advertisements
CREATE TABLE ads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_name TEXT NOT NULL,
  content TEXT NOT NULL,
  target_region_id INTEGER,
  start_date DATE,
  end_date DATE,
  status TEXT DEFAULT 'pending',
  approved_by_official_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (target_region_id) REFERENCES regions(id),
  FOREIGN KEY (approved_by_official_id) REFERENCES officials(id)
);

-- 14. Ad impressions
CREATE TABLE ad_impressions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ad_id INTEGER NOT NULL,
  resident_id INTEGER NOT NULL,
  seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ad_id) REFERENCES ads(id),
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 15. Announcements
CREATE TABLE announcements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  region_id INTEGER NOT NULL,
  official_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  image_url TEXT,
  sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (region_id) REFERENCES regions(id),
  FOREIGN KEY (official_id) REFERENCES officials(id)
);

-- 16. Numbering configuration
CREATE TABLE numbering_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  official_id INTEGER NOT NULL,
  letter_type TEXT NOT NULL,
  prefix TEXT,
  format_template TEXT NOT NULL,
  last_sequence_number INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (official_id) REFERENCES officials(id),
  UNIQUE(official_id, letter_type)
);

-- 17. Numbering overrides
CREATE TABLE numbering_overrides (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numbering_config_id INTEGER NOT NULL,
  new_sequence_number INTEGER NOT NULL,
  reason TEXT,
  set_by_official_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (numbering_config_id) REFERENCES numbering_configs(id),
  FOREIGN KEY (set_by_official_id) REFERENCES officials(id)
);

-- Indexes
CREATE INDEX idx_residents_region ON residents(region_id);
CREATE INDEX idx_residents_family ON residents(family_id);
CREATE INDEX idx_families_no_kk ON families(no_kk);
CREATE INDEX idx_letter_requests_applicant ON letter_requests(applicant_resident_id);
CREATE INDEX idx_letter_requests_status ON letter_requests(status);
CREATE INDEX idx_credits_resident ON credits(resident_id);
CREATE INDEX idx_credit_transfers_from ON credit_transfers(from_resident_id);
CREATE INDEX idx_credit_transfers_to ON credit_transfers(to_resident_id);
CREATE INDEX idx_family_invitations_token ON family_invitations(token);
```

**Note:** The `accounts` table and Rodauth-related tables are automatically created by Rodauth.

---

## 6. ACID Principles for Financial Transactions

All transactions that modify credit balances, sequence numbers, or family consent status must comply with ACID.

- Use explicit transactions `DB.transaction(immediate: true)` in SQLite.
- For credit transfers, deduct the balance only upon confirmation in a single atomic transaction.
- For document number generation, use `SELECT ... FOR UPDATE` (or simply an immediate transaction).

Example in Ruby (Sequel):

```ruby
DB.transaction(immediate: true) do
  credit = Credit.where(resident_id: id).first
  credit.update(balance: credit.balance - amount)
end
```

Example in Go (with SQLite):

```go
tx, err := db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
// ... query
tx.Commit()
```

---

## 7. VIDA Sign Integration

**API Inline Sign:**
- Endpoint: `POST https://api.vida.id/v1/sign/inline`
- Header: `Authorization: Bearer <access_token>`
- Body: `document` (base64 PDF), `signers`, `signature_placement`
- Response: `signed_document` (base64 PDF)

Error handling: Retry 3x by Asynq; after failure, letter status becomes `failed`.

---

## 8. Monitoring & Scaling

| Indicator | Threshold | Action |
|-----------|----------|--------|
| Memory usage | > 75% | Upgrade VPS 2GB → 4GB |
| Swap usage | > 500MB | Upgrade or migrate to PostgreSQL |
| SQLite lock | > 5 seconds | Migrate to PostgreSQL |
| Active RWs | > 10 RWs | Upgrade VPS + migrate to PostgreSQL |

**Monitoring tools:** htop, redis-cli INFO memory, asynqmon, journalctl.

---

## 9. Post-MVP Iteration Plan (Phase 2)

1. RW/Lurah/Camat digital signatures (full hierarchical flow).
2. Dukcapil integration for auto-fill KK members.
3. Digital power of attorney delegation (member representing another member).
4. Automated digital dues payment.
5. Kelurahan/Kecamatan dashboard.
6. Anonymized aggregate data reports.

---

## 10. Milestones (6 weeks)

| Week | Activities | Output |
|------|-----------|--------|
| 1 | Setup VPS (Ubuntu, Redis, Go, wkhtmltopdf). Setup Ruby project: Roda, Sequel, Rodauth, database migrations. | Bot /start running, database ready, Rodauth functional. |
| 2 | Implement Sequel models for all tables. Official authentication via Rodauth (dashboard login). | Officials can log into the dashboard. |
| 3 | Resident management (CSV import), KK registration, member invitations, consent (using Sequel models). | Family head can register and invite members. |
| 4 | Letter request feature (applicant selection), aasm state machine, integration with Sequel. | Letters can be submitted. |
| 5 | Go worker integration (PDF, VIDA Sign callback), custom numbering (using Sequel transactions). | RT digital signature successful. |
| 6 | Credits, credit transfers, dummy top-up, trial run with 1 RT. | MVP ready for launch. |

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Family member has no Telegram | Family head can share invitation link via WhatsApp/SMS. |
| Identity misuse | Unique token verification and consent via the member's own Telegram account. |
| Family head registers someone else's KK | Accept minor risk in MVP. Phase 2: Dukcapil integration. |
| VIDA Sign free tier exhausted | Officials buy credits; residents buy their own. |
| Excessive SQLite locking | WAL mode + busy_timeout; ready to migrate to PostgreSQL. |
| Official forgot password | Rodauth provides password reset via email. |

---

## 12. Conclusion

PRD Final Version 3.1 defines the foundation for building an RT/RW SaaS with minimal operational cost (VPS at $4.2/month) and a sustainable business model. The Family Account feature, ACID compliance, and Ruby+Go architecture are maintained. Using Rodauth and Sequel will accelerate development, enhance security, and ease code maintenance.

**Next step:** Implement the code skeleton according to the PRD.

---

This document is ready to serve as the development reference.
