# Test Plan

> Phased test rollout for this project. Strategy is frozen at the top
> (§1–§5); cookbook patterns at the bottom (§6) fill in as phases ship.
> Read before writing any new test.
>
> Refresh: re-run `/10x-test-plan --refresh` when stale (see §8).
>
> Last updated: 2026-08-02

## 1. Strategy

Tests follow three non-negotiable principles for this project:

1. **Cost × signal.** The cheapest test that gives a real signal for the
   risk wins. Do not promote to e2e because e2e "feels safer." Do not put a
   vision model on top of a deterministic visual diff that already catches
   the regression.
2. **User concerns are first-class evidence.** Risks anchored in "<the
   team is worried about X, and the failure would surface somewhere in
   <area>>" carry the same weight as PRD lines or hot-spot data.
3. **Risks are scenarios, not code locations.** This plan documents *what
   could fail* and *why we believe it's likely* — drawn from documents,
   interview, and codebase *signal* (churn, structure, test base). It does
   NOT claim to know which line owns the failure. That knowledge is
   produced by `/10x-research` during each rollout phase. If the plan and
   research disagree about where the failure lives, research is the
   ground truth.

Hot-spot scope used for likelihood weighting: `app/`, `lib/`, `config/`.

## 2. Risk Map

The top failure scenarios this project must protect against, ordered by
risk = impact × likelihood. Risks are failure scenarios in user / business
terms, not test names. The Source column cites the *evidence that surfaced
this risk* — never a specific file as "where the failure lives" (that is
research's job, see §1 principle #3).

| # | Risk (failure scenario) | Impact | Likelihood | Source (evidence — not anchor) |
|---|---|---|---|---|
| 1 | Logger submits multiple players; session saves with a subset; UI still looks successful so the loss is missed | High | High | interview Q1; hot-spot dir `app/views/game_sessions` (7 commits/30d); PRD US-01 / FR-003–004 |
| 2 | Stimulus nested player rows post a different param shape than request-spec fakes; suite stays green while real submits drop fields | High | High | interview Q2, Q4; hot-spot dirs `app/views/game_sessions`, `app/javascript/controllers`; roadmap S-03 |
| 3 | Confirm/reject wrong: co-player stats include a rejected/pending session, or confirmed session never counts | High | Medium | PRD Business Logic / US-01; roadmap S-03 north star |
| 4 | Abuse: non-owner confirm/reject/edit (IDOR) mutates another user's session or notification | High | Medium | abuse lens (auth product); archive mutual-friend-circle IDOR pattern; S-03 ownership concerns |
| 5 | Edit after log: selective vs bulk re-notify wrong → co-players act on stale scores/game | Medium | Medium | PRD FR-005–006; hot-spot dir `app/services/game_sessions` (4 commits/30d) |
| 6 | Non-friend / invalid registered player accepted on the log (friend-circle gate bypassed) | Medium | Low | PRD US-01 given; user interview edit — deprioritized |

### Risk Response Guidance

| Risk | What would prove protection | Must challenge | Context `/10x-research` must ground | Likely cheapest layer | Anti-pattern to avoid |
|------|-----------------------------|----------------|--------------------------------------|-----------------------|-----------------------|
| #1 | After multi-player submit, persisted participant set matches every submitted player (registered + guest) | "HTTP success / session exists ⇒ all players saved" | create/update entry, participant persistence rule, how partial failure surfaces to the user | request + system (browser submit) | Assert only session count or flash success |
| #2 | Real form DOM (add/remove rows) → POST body the controller accepts; round-trip survivors match what the UI showed | "Request-spec hash equals what Stimulus posts" | field names, nested keys, disabled/hidden fields, Turbo submit path | system (Capybara) | Snapshot HTML only; mirror strong-params as the oracle |
| #3 | Confirm → session in co-player history; reject/pending → excluded; logger's record unchanged | "Notification opened ⇒ stats already updated" | confirm/reject state machine; stats inclusion rule | request / service integration | Happy-path confirm only |
| #4 | Non-participant gets 404/forbidden; target resource unchanged | "Logged-in is enough" | ownership checks on session + notification actions | request | Auth-only smoke without a foreign id |
| #5 | Score-only edit re-notifies selectively; game change bulk; no silent stale inbox | "Any edit ⇒ same notify path" | edit classification; notify fan-out rules | service integration + request | Assert notify count without who/why |
| #6 | Non-accepted friend cannot be tagged as registered co-player | "Any user id in params is fine" | friend-circle gate on create (only if already on the path) | request / unit — opportunistic only | Do not open a dedicated phase for this risk |

## 3. Phased Rollout

Each row is a discrete rollout phase that will open its own change folder
via `/10x-new`. Status moves left-to-right through the values below; the
orchestrator updates Status as artifacts appear on disk.

| # | Phase name | Goal (one line) | Risks covered | Test types | Status | Change folder |
|---|---|---|---|---|---|---|
| 1 | Session-form player fidelity | Prove multi-player submit persists all players via real form POST | #1, #2 | system (+ tighten request oracles) | not started | — |
| 2 | Confirm path & ownership | Defend confirm/reject semantics and IDOR on session/notification actions | #3, #4 | request + service integration | done | `confirm-path-ownership` |
| 3 | Edit re-notify coverage | Cover edit notify matrix (selective vs bulk); #6 only if cheap on create path | #5 | request + service integration | not started | — |
| 4 | System-spec CI floor | Wire Capybara/system runner into CI; fill cookbook §6 for system specs | cross-cutting | gates | not started | — |

## 4. Stack

The classic test base for this project. AI-native tools (if any) carry a
`checked:` date so future readers can see which lines need re-verification.
Recommendations in this section must be grounded in local manifests/configs
plus the MCP/tools actually exposed in the current session.

| Layer | Tool | Version | Notes |
|------|------|---------|-------|
| unit + integration | RSpec + rspec-rails | ~> 8.0 | Models, service unit/integration, request specs; `bin/rspec`; FactoryBot |
| HTTP edge mocking | WebMock | ~> 3.26 | Used for Wikidata/catalog import; keep at network edge |
| e2e / browser | Capybara system specs | none yet — see §3 Phase 1 + 4 | rspec-rails recommends system specs for browser flows; no Capybara in Gemfile today |
| accessibility | none yet | — | Not in MVP test budget |
| AI-native | none | n/a | No Playwright/browser MCP in session; do not layer vision on deterministic system asserts |

**Test-base profile:** meaningful — RSpec configured; 22 spec files across models, requests, and services; CI already runs `bin/rspec`. Gap: no browser-driven system specs (interview Q4).

**Stack grounding tools (current session):**
- Docs: Context7 (`/rspec/rspec-rails`) — request specs preferred over controller specs; system specs for browser e2e; checked: 2026-08-01
- Search: Exa available — not used (docs MCP sufficient); checked: 2026-08-01
- Runtime/browser: none (no Playwright MCP); checked: 2026-08-01
- Provider/platform: Railway MCP — deploy/status only, not a test gate; checked: 2026-08-01

## 5. Quality Gates

The full set of gates that must pass before a change reaches production.
"Required for §3 Phase \<N\>" means the gate is enforced once that rollout
phase lands; before that, the gate is `planned`.

| Gate | Where | Required? | Catches |
|------|-------|-----------|---------|
| RuboCop + Brakeman + bundler-audit + importmap audit | local `bin/ci` + GHA | required (already wired) | lint / security drift |
| unit + request + service specs | local + CI (`bin/rspec`) | required (already wired) | logic regressions |
| system specs on session-form critical path | local + CI | required after §3 Phase 4 (specs land in Phase 1) | FE param shape vs controller digest; silent player drop |
| full auth e2e / Wikidata browser flows | — | deliberately out | see §7 |
| post-edit AI hook / multimodal visual review | — | not planned | cost × signal not justified for MVP |

## 6. Cookbook Patterns

How to add new tests in this project. Each sub-section is filled in once
the relevant rollout phase ships; before that, the sub-section reads
"TBD — see §3 Phase \<N\>."

### 6.1 Adding a unit / model / service unit test

- Prefer `spec/models/` for scopes/enums (e.g. `GameSession.visible_to`,
  participant status) and `spec/services/unit/` for single-service branches.
- For confirm/ownership: model specs backup the inclusion rule; they do
  **not** replace HTTP oracles in §6.5.
- Follow naming/matchers from the nearest sibling `_spec.rb`. See also
  `spec/AGENTS.md`.
- **Run locally:** `bin/rspec`.

### 6.2 Adding a request or service integration test

- Prefer request specs for HTTP surfaces (`spec/requests/`); use
  `spec/services/integration/` for multi-model lifecycles without asserting
  the full browser path.
- Confirm/reject + IDOR oracles: follow §6.5. Edit re-notify matrix: TBD —
  see §3 Phase 3.
- Auth in request specs: `sign_in_as` / `sign_out` from
  `spec/support/authentication_helpers.rb`.
- **Run locally:** `bin/rspec`.

### 6.3 Adding a system (browser) test

- TBD — see §3 Phase 1 for session-form player-fidelity pattern; Phase 4 for CI runner wiring.
- Goal pattern: drive add/remove player rows in the real form; assert persisted participants match UI — not hand-built param hashes alone.

### 6.4 Adding a test for session create/update player persistence

- TBD — see §3 Phase 1 (Risks #1–#2): prove every submitted registered + guest player survives save.

### 6.5 Adding a test for confirm/reject or notification ownership

Covers Risks #3–#4. Layer: **request** (cheapest that hits the user-visible
surface). Inclusion rule in production is `GameSession.visible_to` — logger
via `creator`, co-player only when `GameSessionParticipant` is `confirmed`.
Until S-04 stats exist, treat `GET /game_sessions` as the history/stats
oracle. Future stats **must reuse `visible_to`** (or equivalent); do not
aggregate `user.game_session_participations` without `.confirmed` plus the
creator OR.

**Risk #3 — confirm/reject ↔ history**

1. Setup: logger’s session, tagged friend pending, unread notification.
2. `PATCH` confirm or reject as the friend.
3. As the friend (and logger where relevant), `GET /game_sessions` and
   assert body include/exclude by game name.
4. Also cover: pending friend never listed; logger still listed after friend
   rejects.

Canonical examples: `spec/requests/notifications_spec.rb` (confirm/reject →
index), `spec/requests/game_sessions_spec.rb` (pending exclusion).

**Risk #4 — IDOR / ownership**

1. Sign in as a user who does **not** own the resource.
2. Act on a foreign id (`PATCH` confirm/reject, `PATCH` session update,
   friendship accept/decline/cancel).
3. Expect **404** (scoped find → `RecordNotFound`; not 403).
4. Reload and assert the target is **unchanged** (status, `read_at`,
   scores/`game_id`, friendship parties — as applicable).

Canonical examples: `spec/requests/notifications_spec.rb`,
`spec/requests/game_sessions_spec.rb`, `spec/requests/friendships_spec.rb`
(foreign-id examples titled “…and leaves … unchanged”).

Anti-patterns: happy-path confirm only; auth smoke without a foreign id;
asserting 404 without “resource unchanged.”

- **Run locally:** `bin/rspec`.

### 6.6 Per-rollout-phase notes

- **§3 Phase 2 (`confirm-path-ownership`, 2026-08-02):** Request oracles for
  Risks #3–#4. Friendship IDOR examples were aligned in the same change to
  the shared “404 + target unchanged” contract (not deferred to a follow-up).

## 7. What We Deliberately Don't Test

Exclusions agreed during the rollout (Phase 2 interview, Q5). Future
contributors should respect these unless the underlying assumption changes.

- **Wikidata SPARQL / catalog import depth** — operator-only; existing unit + WebMock integration is enough. Re-evaluate if end users ever hit live import. (Source: Phase 2 interview Q5.)
- **Full e2e coverage of auth / password-reset paths** — request specs already guard the HTTP surface; do not spend system-spec budget here. Re-evaluate if auth UX becomes Stimulus-heavy like the session form. (Source: Phase 2 interview Q5.)
- **Friend-circle gate as a dedicated phase** — Risk #6 kept on the map at Medium × Low; cover only opportunistically on the create path. Re-evaluate if tagging non-friends becomes a recurring incident. (Source: user edit on seed brief.)

## 8. Freshness Ledger

- Strategy (§1–§5) last reviewed: 2026-08-01
- Stack versions last verified: 2026-08-01
- AI-native tool references last verified: 2026-08-01

Refresh (`/10x-test-plan --refresh`) when:

- a new top-3 risk surfaces from the roadmap or archive,
- a recommended tool's `checked:` date is older than three months,
- the project's tech stack changes (new framework, new test runner),
- §7 negative-space no longer matches what the team believes.
