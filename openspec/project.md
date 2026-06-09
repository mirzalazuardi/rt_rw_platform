# openspec/project.md — Technical Reference

## Tech Stack & Versions

| Layer | Technology | Version target |
|---|---|---|
| Ruby | MRI | 3.3.x |
| Roda | Web framework | ~> 3.x |
| Rodauth | Auth | ~> 2.x |
| Sequel | ORM + migrations | ~> 5.x |
| AASM | State machine | ~> 5.x |
| Telegem | Telegram bot | latest |
| Go | Worker runtime | 1.22.x |
| Asynq | Job queue | ~> 0.24 |
| wkhtmltopdf | PDF generation | 0.12.6 |
| Redis | Broker / cache | 7.x |
| SQLite | DB (MVP) | 3.45+ (WAL) |
| Kamal | Deployment | ~> 2.x |
| Docker | Container runtime | 25.x |

## File Structure

```
rt_rw_platform/
├── app/                        # Ruby (Roda) backend
│   ├── config/
│   │   ├── database.rb         # Sequel connection
│   │   └── rodauth.rb          # Rodauth configuration
│   ├── db/
│   │   └── migrations/         # Sequel migration files
│   ├── models/                 # Sequel models
│   ├── routes/                 # Roda route blocks
│   │   ├── api/                # Resident Mini App endpoints
│   │   └── dashboard/          # Official web dashboard
│   ├── services/               # Business logic (plain Ruby objects)
│   ├── spec/                   # RSpec tests
│   │   ├── models/
│   │   ├── routes/
│   │   └── services/
│   ├── Gemfile
│   └── config.ru
├── worker/                     # Go (Asynq) worker
│   ├── cmd/worker/main.go
│   ├── handlers/               # Asynq task handlers
│   │   ├── pdf.go
│   │   └── sign.go
│   ├── pkg/
│   │   ├── pdf/
│   │   └── vida/
│   └── go.mod
├── config/
│   └── deploy.yml              # Kamal deploy config
├── openspec/
│   ├── AGENTS.md
│   ├── project.md
│   └── changes/                # Proposals keyed by kebab-id
├── .env.example
├── .gitignore
├── CLAUDE.md
├── AGENTS.md
└── README.md
```

## Testing Approach

- **TDD always**: write a failing spec before any implementation code.
- Ruby: RSpec with `rack-test` for route specs, `database_cleaner` (truncation strategy).
- Go: standard `testing` package + `testify` for assertions.
- No mocking of the database in either language — use a real SQLite test DB.
- CI must pass before merging: `bundle exec rspec` + `go test ./...`.

## Git & PR Conventions

Commits: lowercase, no period, imperative (`add family registration route`).  
Branch: `feature/<kebab>`, `fix/<kebab>`, `chore/<kebab>`.  
PRs: one capability slice per PR, linked to a `tasks.md` task ID.  
Never force-push `main`.

## Constraints

- VPS: 2 CPU cores, 2 GB RAM — keep memory footprint minimal.
- Budget: $4.2/month VPS; no paid managed services in MVP.
- SQLite WAL must handle all MVP load; migrate to PostgreSQL when > 10 active RWs
  or swap > 500 MB.
- VIDA Sign: 10 free signatures initially — each official gets their own quota.
- Telegram Mini App: HTML + Vanilla JS only (no React/Vue in MVP).

## What NOT to Do

- Do not use ActiveRecord, Rails, or Sinatra.
- Do not introduce a message queue other than Asynq/Redis.
- Do not store plaintext credentials — encrypt VIDA keys in the `officials` table.
- Do not write raw SQL in models — use Sequel dataset methods.
- Do not use `DB.transaction` without `immediate: true` for write-heavy operations
  on SQLite.
- Do not add a feature without a spec file in `spec/`.

## Letter Types (`letter_type`)

Valid values for the `letter_type` column in `letter_requests` and `numbering_configs`:

| Nilai | Template | Keterangan |
|---|---|---|
| `ktp` | `templates/surat_pengantar_ktp.md` | Pengantar pembuatan/perpanjangan KTP |
| `kk` | `templates/surat_pengantar_kk.md` | Pengantar pembuatan/perubahan KK |
| `domisili` | `templates/surat_keterangan_domisili.md` | Keterangan domisili/tempat tinggal |
| `sktm` | `templates/surat_keterangan_tidak_mampu.md` | Keterangan tidak mampu (ekonomi) |
| `pindah` | `templates/surat_pindah.md` | Keterangan pindah tempat tinggal |

Add a CHECK constraint or model validation when new types are introduced.
`sktm` and `pindah` require a Sequel migration adding a `CHECK` constraint to
`letter_requests.letter_type` once the table is created.

## Open Questions

- Dukcapil API integration for KK auto-fill — Phase 2 only, skip in MVP.
- RW secretary dashboard scope — basic read-only report view in MVP.
- Payment gateway choice — default Midtrans; Xendit as fallback if Midtrans
  sandbox is unavailable.
