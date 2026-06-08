---
project: all-aBoard
version: 1
status: draft
created: 2026-05-31
updated: 2026-06-07
prd_version: 1
main_goal: speed
top_blocker: time
---

# Roadmap: all-aBoard

> Derived from `context/foundation/prd.md` (v1) + auto-researched codebase baseline.
> Edit-in-place; archive when superseded.
> Slices below are listed in dependency order. The "At a glance" table is the index.

## Vision recap

Board-game hobbyists in overlapping friend circles have no shared place to log who played, scores, and which circle a night belonged to. all-aBoard coordinates session results after game nights: registered players share and confirm participation; unregistered players at the table stay name-and-score only on the log.

The product wedge — the one trait that, if removed, makes this a generic score tracker — is **mixed registered and unregistered players on one session**, with **confirm/reject** before a co-player's stats count the session.

## North star

**S-03: log session with confirm flow** — Delivers US-01 end-to-end: catalog game, registered friend + unregistered guest, in-app notification, confirm/reject, logger sees the session immediately.

> **North star** here means the smallest end-to-end slice that proves the core hypothesis — shared session tracking with optional co-player consent — placed as early as prerequisites allow. Everything earlier (auth, friends) exists only to make this slice possible.

## At a glance

| ID | Change ID | Outcome (user can …) | Prerequisites | PRD refs | Status |
|---|---|---|---|---|---|
| F-01 | minimal-auth-scaffold | (foundation) email/password auth scaffold: User model, sessions, protected routes | — | FR-001, Access Control | done |
| F-02 | seed-game-catalog | (foundation) Wikidata import service + ~20-game MVP seed via console | F-01 | FR-009, Business Logic | planning |
| F-03 | tailwind-daisyui-setup | (foundation) Tailwind CSS + daisyUI in asset pipeline; base theme and component classes in ERB | — | — | implemented |
| S-01 | email-password-auth | create an account, log in, and log out | F-01 | FR-001, US-01 | ready |
| S-02 | mutual-friend-circle | send a friend request; accept or decline; see active friends | S-01 | FR-002, US-01 | proposed |
| S-03 | log-session-with-confirm | log a session with catalog game, registered friend, and unregistered player; co-player gets in-app notification and confirms or rejects; logger sees history immediately | S-02, F-02 | US-01, FR-003, FR-004, FR-005, FR-006, FR-009 | proposed |
| S-04 | session-stats-filters | view statistics for sessions they participated in, with filters | S-03 | FR-007 | proposed |

## Streams

Navigation aid — groups items that share a Prerequisites chain. Canonical ordering still lives in the dependency graph below.

| Stream | Theme | Chain | Note |
|---|---|---|---|
| A | MVP path | `F-01` → `S-01` → `S-02` → `S-03` → `S-04` | Speed bias: strict must-have order through north star (`S-03`) then stats. |
| B | Catalog import | `F-02` | Wikidata adapter for MVP; provider switch deferred to P-07. Runs parallel with `S-02` after `F-01`; joins main path at `S-03`. |
| C | UI styling | `F-03` | Independent of MVP path; no prerequisites — can land anytime to polish product UI in any slice. |

## Baseline

What's already in place in the codebase as of `2026-05-31` (auto-researched + user-confirmed).
Foundations below assume these are present and do NOT re-scaffold them.

- **Frontend:** partial — Hotwire (Turbo + Stimulus) via importmap (`config/importmap.rb`); ERB home page only (`app/views/pages/home.html.erb`); no product UI
- **Backend / API:** partial — Rails 8.1 + Puma (`Gemfile`); `root` and `/up` only (`config/routes.rb`); no domain controllers
- **Data:** partial — PostgreSQL configured (`config/database.yml`); `db/schema.rb` version 0, no tables; no migrations under `db/migrate/`
- **Auth:** absent — per `tech-stack.md` email/password in scope; no User model or auth gems in code
- **Deploy / infra:** partial — `Dockerfile`, `railway.toml`, GitHub Actions quality gates (`.github/workflows/ci.yml`); deploy narrative in `context/foundation/infrastructure.md`
- **Observability:** partial — Rails default logging + `/up` healthcheck; no error-tracking gem in `Gemfile`

## Foundations

### F-01: Minimal auth scaffold

- **Outcome:** (foundation) User model, email/password credentials, session issuance, and route protection are in place for vertical slices to build on.
- **Change ID:** minimal-auth-scaffold
- **PRD refs:** FR-001, Access Control (email + password MVP)
- **Unlocks:** S-01, S-02, S-03 (all require authenticated users)
- **Prerequisites:** —
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Sequenced first because baseline reports auth absent; without it no slice is plannable. Kept minimal — full login UX ships in S-01.
- **Status:** done

### F-02: Import game catalog

- **Outcome:** (foundation) Reusable operator import service with a **Wikidata adapter** fetches board-game data (CC0), persists `Game` records locally, and accepts a parameterized batch. F-02 seeds ~20 titles for development and S-03 via Rails console; the same service supports wide-catalog operator imports later (P-03 wraps UI and auth only). No user or admin catalog editing in MVP. Switching or adding another provider (e.g. BoardGameGeek) is post-MVP (P-07).
- **Change ID:** seed-game-catalog
- **PRD refs:** FR-009, Business Logic (catalog on session log), Open Questions (catalog seeding, provider — Wikidata for MVP)
- **Unlocks:** S-03 (game picker on session log); P-03 (admin UI wraps same import service)
- **Prerequisites:** F-01
- **Parallel with:** S-02
- **Blockers:** —
- **Unknowns:** Wikidata client gem choice, fields to persist, `wikidata_id` (and optional `bgg_id` cross-ref) as idempotency keys — resolve in `/10x-plan`. Batching and Wikidata query rate courtesy are in F-02 scope even when MVP only imports ~20 titles.
- **Risk:** Wikidata coverage and field quality vary by title; session flow reads local catalog only — no user-facing live lookup in MVP. Richer metadata or BGG licensing deferred to P-07.
- **Change folder:** [seed-game-catalog](../changes/seed-game-catalog/change.md)
- **Status:** planning

### F-03: Tailwind CSS + daisyUI setup

- **Outcome:** (foundation) Tailwind CSS and daisyUI are integrated via `tailwindcss-rails` (standalone CLI + npm for daisyUI plugin); abyss theme; base layout shell with nav placeholder, flash partial, and page container.
- **Change ID:** tailwind-daisyui-setup
- **PRD refs:** —
- **Unlocks:** S-01, S-02, S-03, S-04 (polished product UI in any vertical slice; none blocked without it)
- **Prerequisites:** —
- **Parallel with:** S-01, S-02, F-02
- **Blockers:** —
- **Unknowns:** daisyUI theme choice (e.g. `corporate`, `business`, `nord`) — pick during `/10x-plan`
- **Risk:** Additive infra; hand-written CSS removed; auth views remain unstyled until S-01.
- **Status:** implemented

## Slices

### S-01: Email/password auth

- **Outcome:** user can create an account, log in, and log out.
- **Change ID:** email-password-auth
- **PRD refs:** FR-001, US-01
- **Prerequisites:** F-01 ([minimal-auth-scaffold](../archive/2026-06-02-minimal-auth-scaffold/plan.md#impl-review-addendum-2026-06-04) — carry forward impl-review deferrals below)
- **Carry-forward from F-01 impl review** ([plan addendum](../archive/2026-06-02-minimal-auth-scaffold/plan.md#impl-review-addendum-2026-06-04)): session cookie TTL + server-side active scope; `Session.sweep` (index on `sessions.created_at` already landed); staging `secure:` cookie if needed; ambiguous registration errors (no email enumeration)
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** Auth views use bare HTML from F-01 scaffold — restyle with daisyUI form/input/btn classes (F-03 provides the foundation).
- **Risk:** First user-visible slice; proves deploy path still works with real users before friend/session complexity.
- **Status:** ready

### S-02: Mutual friend circle

- **Outcome:** user can send a friend request to another registered user; the other user can accept or decline; friendship is active only after mutual acceptance.
- **Change ID:** mutual-friend-circle
- **PRD refs:** FR-002, US-01
- **Prerequisites:** S-01
- **Parallel with:** F-02
- **Blockers:** —
- **Unknowns:** —
- **Risk:** US-01 requires at least one accepted friend; deferring this blocks the north star even if session UI were started early.
- **Status:** proposed

### S-03: Log session with confirm flow

- **Outcome:** user can log a played session with a game from the catalog, a registered friend, and an unregistered player (name + score only); the registered friend receives an in-app notification and can confirm or reject; the logger sees the session in their history and stats immediately after save.
- **Change ID:** log-session-with-confirm
- **PRD refs:** US-01, FR-003, FR-004, FR-005, FR-006, FR-009
- **Prerequisites:** S-02, F-02
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** North star — concentrates confirm/reject business rules and mixed player types; highest integration risk, sequenced only after auth, friends, and catalog exist.
- **Status:** proposed

### S-04: Session statistics with filters

- **Outcome:** user can view statistics for sessions they participated in (as logger or confirmed co-player), with filters.
- **Change ID:** session-stats-filters
- **PRD refs:** FR-007
- **Prerequisites:** S-03
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Depends on real session and confirm/reject data from S-03; completing the PRD primary Success Criteria step 6 without expanding scope beyond FR-007.
- **Status:** proposed

## Backlog Handoff

Issue URLs and board setup: @context/foundation/backlog.md.

| Roadmap ID | Change ID | Suggested issue title | Ready for `/10x-plan` | Notes |
|---|---|---|---|---|
| F-01 | minimal-auth-scaffold | Scaffold email/password auth (User, sessions, protection) | — | Done (archived) |
| F-02 | seed-game-catalog | Import game catalog from Wikidata (~20-game MVP seed, console) | yes | F-01 done; Wikidata adapter only |
| F-03 | tailwind-daisyui-setup | Add Tailwind CSS + daisyUI (tailwindcss-rails, base theme) | yes | No prerequisites; parallel with S-01 / S-02 / F-02 |
| S-01 | email-password-auth | Sign up, log in, log out | yes | F-01 done; carry forward F-01 impl-review deferrals |
| S-02 | mutual-friend-circle | Friend requests with mutual acceptance | no | After S-01 |
| S-03 | log-session-with-confirm | Log session + in-app confirm/reject (US-01) | no | North star; after S-02 and F-02 |
| S-04 | session-stats-filters | Personal session stats with filters | no | After S-03 |

## Open Roadmap Questions

_No cross-cutting roadmap questions. PRD `## Open Questions` were resolved 2026-05-21 (login mechanism, friend-circle policy); catalog seeding re-resolved 2026-06-05 (import service, console invocation); catalog provider for MVP set to Wikidata 2026-06-07 (switch/evaluation → P-07)._

## Parked

- **FR-008: recommended-games list** — Why parked: nice-to-have per PRD; not on primary Success Criteria path; defer while `main_goal` is speed and `top_blocker` is time.
- **Per-game ratings** — Why parked: PRD Non-Goals.
- **Admin account / catalog curation** — Why parked: PRD Non-Goals; flat users only in MVP. F-02 delivers the import service; P-03 adds admin auth + UI around it.
- **Push notifications** — Why parked: PRD Non-Goals; in-app inbox only in v1.
- **User-facing external game lookup** — Why parked: PRD Non-Goals; no live third-party search during session log (P-05).
- **Game cover images** — Why parked: game picker works as text list for MVP; Wikidata P18 rarely has recognizable box art (Commons hosts component photos, not covers); hosting/thumbnailing requires Active Storage or external bucket not yet configured. Middle ground (nullable `image_url` column + Commons URL) can be added in a single migration when S-03 UI calls for it. Roadmap **P-08** (`game-catalog-images`).
- **Catalog provider switch (e.g. BoardGameGeek)** — Why parked: MVP ships Wikidata adapter only (F-02); legal/licensing and richer metadata re-evaluation deferred until after MVP. May add a second adapter or replace Wikidata behind the same import service — not committed. Roadmap **P-07** (`catalog-provider-switch`).
- **Team workspaces / formal leagues** — Why parked: PRD Non-Goals.

## Done

- **F-01: (foundation) User model, email/password credentials, session issuance, and route protection are in place for vertical slices to build on.** — Archived 2026-06-04 → `context/archive/2026-06-02-minimal-auth-scaffold/`. Lesson: —.
