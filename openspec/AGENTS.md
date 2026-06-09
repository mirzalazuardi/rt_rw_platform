# openspec/AGENTS.md — Workflow Rules for AI Agents

## Session Start
1. Read `CLAUDE.md` (root) for project overview and style guide.
2. Read `openspec/project.md` for stack versions, file structure, conventions.
3. Check `openspec/changes/` for the active proposal before writing any code.
4. Run `codegraph_status` — if not initialized, ask the user to run `codegraph init -i`.

## Codebase Exploration
Prefer `codegraph_*` tools for structural questions (symbol lookup, call chains,
impact analysis). Fall back to Grep/Read only for literal text (log messages,
comments, string contents).

## Change vs Direct Edit
- **Proposal exists** (`openspec/changes/<id>/tasks.md`) → execute tasks from it.
- **No proposal** → create one before touching production code. Exception: typos,
  doc-only changes, and failing-test fixes may be done directly.

## Task Granularity
| Complexity | Task size | Rule |
|---|---|---|
| LOW | ≤ 30 min each | Single file or method change |
| MID | ≤ 2 h each | One feature slice (model + route + spec) |
| HIGH | ≤ half-day each | Cross-cutting (auth, state machine, worker) |

Each task in `tasks.md` must be **atomic**: self-contained, independently runnable,
and verifiable by a test or curl command.

## Skill Triggers
| Situation | Skill |
|---|---|
| New feature / refactor | `rails-expert` or `fullstack-dev-skills:rails-expert` |
| Security-sensitive code | `security-reviewer` |
| Debugging a failure | `superpowers:systematic-debugging` |
| Code review requested | `superpowers:requesting-code-review` |
| Writing a new plan | `superpowers:writing-plans` |

## Hard Rules
- Never push, merge, or rebase without explicit user confirmation.
- Never skip `--no-verify` or bypass RSpec on commit.
- All DB changes go through Sequel migrations — no `sequel -m` shorthand in prod.
- Financial transactions (`credits`, `credit_transfers`) must use
  `DB.transaction(immediate: true)`.
- Telegram `initData` must be validated server-side on every resident API request.

## Handoff
End each session with: files changed, tests status, next task ID from `tasks.md`.

## Project-Specific
- Ruby lives in `app/`; Go lives in `worker/`. Keep them independent.
- Kamal config lives in `config/deploy.yml`. Never edit Docker images manually.
- `.env` is gitignored. Update `.env.example` when adding a new variable.
