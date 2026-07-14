# Test Plan

> Phased test rollout for this project. Strategy is frozen at the top
> (§1–§5); cookbook patterns at the bottom (§6) fill in as phases ship.
> Read before writing any new test.
>
> Refresh: re-run `/10x-test-plan --refresh` when stale (see §8).
>
> Last updated: 2026-07-14

## 1. Strategy

Tests follow three non-negotiable principles for this project:

1. **Cost × signal.** The cheapest test that gives a real signal for the
   risk wins. Do not promote to e2e because e2e "feels safer." Do not put a
   vision model on top of a deterministic visual diff that already catches
   the regression.
2. **User concerns are first-class evidence.** Risks anchored in "the team
   is worried about X, and the failure would surface somewhere in session
   or stats flows" carry the same weight as PRD lines or hot-spot data.
3. **Risks are scenarios, not code locations.** This plan documents *what
   could fail* and *why we believe it's likely* — drawn from documents,
   interview, and codebase *signal* (churn, structure, test base). It does
   NOT claim to know which line owns the failure. That knowledge is
   produced by `/10x-research` during each rollout phase. If the plan and
   research disagree about where the failure lives, research is the
   ground truth.

Hot-spot scope used for likelihood weighting: `app/`, `config/`, `lib/`,
`spec/` (180-day window; 30-day window had insufficient history).

## 2. Risk Map

The top failure scenarios this project must protect against, ordered by
risk = impact × likelihood. Risks are failure scenarios in user / business
terms, not test names. The Source column cites the *evidence that surfaced
this risk* — never a specific file as "where the failure lives" (that is
research's job, see §1 principle #3).

| # | Risk (failure scenario) | Impact | Likelihood | Source (evidence — not anchor) |
|---|-------------------------|--------|------------|--------------------------------|
| 1 | User views session statistics for games or sessions they did not participate in (as logger or confirmed co-player) | High | High | interview Q1; PRD guardrails (Privacy); roadmap S-04 |
| 2 | Co-player stats are wrong: session counts before they confirm, stays after they reject, or remains pending with no resolution path | High | High | interview Q3, Q4; PRD Business Logic; roadmap S-03 (north star) |
| 3 | Logger saves a session but it is missing from their own history or stats immediately after submit | High | Medium | PRD Success Criteria step 3; FR-003 guardrail |
| 4 | User confirms, rejects, or reads session details for a session they were not invited to (IDOR — logged in but not a participant) | High | Medium | abuse lens (authorization); interview Q1; PRD FR-006 |
| 5 | Unregistered guest player incorrectly gets an account, login path, or stats view; or a registered player is stored as name-only guest data | Medium | High | PRD US-01 wedge; PRD Non-Functional (unregistered players) |
| 6 | User tags a registered co-player who is not an accepted friend and the session incorrectly succeeds (or wrongly fails when the friend is accepted) | Medium | Medium | interview correction; PRD FR-002 + FR-003; user rule: friends-only for registered tags; NPC-only sessions allowed |
| 7 | Registered co-player included in a logged session receives no in-app notification to confirm or reject | Medium | Medium | PRD FR-005; PRD Success Criteria step 4 |

### Risk Response Guidance

| Risk | What would prove protection | Must challenge | Context `/10x-research` must ground | Likely cheapest layer | Anti-pattern to avoid |
|------|-----------------------------|----------------|--------------------------------------|-----------------------|-----------------------|
| #1 | A user querying stats sees only sessions they logged or confirmed; another user's sessions never appear in their filtered results | "Authenticated user can query stats" implies scoping is correct | Stats query entry point, participation predicate (logger vs confirmed co-player), filter parameters, negative case user pair | integration request spec | Asserting total row count from fixture setup without verifying the requesting user's scope |
| #2 | After co-player rejects, their stats exclude the session; after confirm, stats include it; before response, their stats do not count it; logger stats always include it | "Session saved" implies all participants' stat views are immediately correct | Confirm/reject state machine, stat aggregation queries, logger vs co-player visibility rules, pending state | model scope spec + integration spec | Oracle copied from the same aggregation method under test |
| #3 | Logger submits a valid session (NPC-only or with registered friend) and their history/stats list includes it on the next read without waiting for co-player action | "Create returns 200" implies read-your-writes for the logger | Session create endpoint, immediate visibility query, transaction boundaries | integration request spec | Testing only the create response body without a follow-up history/stats read |
| #4 | Non-participant authenticated user receives 404 or 403 on confirm, reject, and show — not the session payload | "User is logged in" equals "user may act on this session" | Notification/inbox routing, session participant membership check, HTTP status for unauthorized actor | integration request spec | Testing only the happy-path participant; skipping cross-user negative examples |
| #5 | Guest rows persist as name + score only with no user foreign key; registered tags resolve to real users and are distinguishable from guests | "Name field present" means the player is a guest | Player join model, guest vs registered discriminator, validation on create | model spec + integration spec | Factory that always creates users, masking guest path |
| #6 | Session with only NPC players saves without friend check; session tagging a registered user succeeds only when mutual friendship is active; non-friend tag is rejected | "Registered player selected" does not require friendship (user correction: friends-only for registered tags) | Friend-circle active state, session player validation, NPC-only path vs registered-tag path | integration request spec | Requiring accepted friend even when all players are guests |
| #7 | After session save including a registered friend, that friend's inbox contains a notification referencing the session | "Notification model exists" implies delivery on create | Notification creation trigger, inbox listing endpoint, idempotency on re-save | integration spec | Asserting only DB row exists without inbox read by the recipient user |

## 3. Phased Rollout

Each row is a discrete rollout phase that will open its own change folder
via `/10x-new`. Status moves left-to-right through the values below; the
orchestrator updates Status as artifacts appear on disk.

| # | Phase name | Goal (one line) | Risks covered | Test types | Status | Change folder |
|---|------------|-----------------|---------------|------------|--------|---------------|
| 1 | Session log + confirm/reject critical path | Prove north-star session rules: logger visibility, guest handling, friend-only registered tags, confirm/reject stat gating, notification delivery | #2, #3, #5, #6, #7 | model + integration (request/service) | change opened | context/changes/testing-session-log-confirm-critical-path/ |
| 2 | Authorization + stats privacy boundaries | Prove IDOR protection on session actions and stats scoping so users never see another person's data | #1, #4 | integration request specs | not started | — |
| 3 | Quality-gates + cookbook wiring | Lock test patterns in CI and fill §6 cookbook so future tests follow one convention | cross-cutting | gates + docs | not started | — |

## 4. Stack

The classic test base for this project. AI-native tools (if any) carry a
`checked:` date so future readers can see which lines need re-verification.
Recommendations in this section must be grounded in local manifests/configs
plus the MCP/tools actually exposed in the current session.

| Layer | Tool | Version | Notes |
|-------|------|---------|-------|
| unit + integration | RSpec + rspec-rails | ~8.0 | Primary runner; `bin/rspec`; request specs preferred for HTTP (per `spec/AGENTS.md`) |
| factories | FactoryBot Rails | ~6.5 | `create(:user)` etc.; mirror `app/` layout under `spec/` |
| API mocking | WebMock | ~3.26 | External HTTP only (Wikidata); never mock internal domain modules |
| e2e / system | none yet | — | Capybara not configured; see §7 — not prioritized for MVP |
| accessibility | none | — | — |
| (optional) AI-native | none | n/a | No AI-native test layer in rollout; cost × signal favors deterministic specs |

**Stack grounding tools (current session):**
- Docs: Context7 (`/rspec/rspec-rails`) — request vs system spec guidance; checked: 2026-07-14
- Search: Exa.ai — available, not used for this write; checked: 2026-07-14
- Runtime/browser: none — system specs possible via Capybara but not configured; not used; checked: 2026-07-14
- Provider/platform: Railway MCP — deploy/log gates possible in Phase 3; not used yet; checked: 2026-07-14

Test-base profile: **sparse** — RSpec configured, 11 spec files clustered in
auth and game-catalog areas; friends, sessions, and stats domains untested.

## 5. Quality Gates

The full set of gates that must pass before a change reaches production.
"Required for §3 Phase N" means the gate is enforced once that rollout
phase lands; before that, the gate is `planned`.

| Gate | Where | Required? | Catches |
|------|-------|-----------|---------|
| RuboCop | local + CI (`bin/ci`) | required | style / omakase drift |
| Brakeman + bundler-audit + importmap audit | local + CI | required | security regressions |
| RSpec (unit + integration) | local + CI | required (baseline); patterns extended after §3 Phase 1 | logic regressions in auth + catalog; session domain after Phase 1 |
| e2e on critical flows | CI on PR | planned — not in rollout | — |
| post-edit hook | local (agent loop) | planned — not in rollout | — |
| visual diff (deterministic) | CI on PR | excluded per §7 | — |
| pre-prod smoke | between merge + prod | optional | environment-specific failures |

## 6. Cookbook Patterns

How to add new tests in this project. Each sub-section is filled in once
the relevant rollout phase ships; before that, the sub-section reads
"TBD — see §3 Phase N."

### 6.1 Adding a model spec

- TBD — see §3 Phase 1 (session participant and confirm/reject scopes).

### 6.2 Adding a request spec

- **Location**: `spec/requests/` (mirrors HTTP surface).
- **Naming**: `<feature>_spec.rb`.
- **Reference test**: `spec/requests/authentication_spec.rb`.
- **Run locally**: `bin/rspec spec/requests/<file>_spec.rb`.
- **Auth helpers**: `spec/support/authentication_helpers.rb` (`sign_in_as`, `register_user`).

### 6.3 Adding a service unit spec

- **Location**: `spec/services/unit/<domain>/`.
- **Reference test**: `spec/services/unit/game_catalog/import_service_spec.rb`.
- **Run locally**: `bin/rspec spec/services/unit/<path>_spec.rb`.

### 6.4 Adding a service integration spec

- TBD — see §3 Phase 1 (session log + confirm/reject flow pattern).

### 6.5 Adding a test for session privacy / IDOR

- TBD — see §3 Phase 2 (cross-user negative request spec pattern).

### 6.6 Per-rollout-phase notes

(Optional — filled as phases ship.)

## 7. What We Deliberately Don't Test

Exclusions agreed during the rollout (Phase 2 interview, Q5). Future
contributors should respect these unless the underlying assumption changes.

- **View/CSS styling** — daisyUI classes, layout polish, and snapshot tests
  break often and do not catch session/stat regressions. Re-evaluate if
  visual regressions become user-visible production incidents. (Source:
  Phase 2 interview Q5.)
- **Full browser E2E for every slice** — request + integration specs give
  cheaper signal for this MVP; system specs not configured. (Source: cost ×
  signal principle + sparse solo timeline.)
- **Wikidata mapper/client internals beyond existing coverage** — catalog
  import already has unit + integration specs; session work is higher risk.
  (Source: test-base profile + roadmap priority.)

## 8. Freshness Ledger

- Strategy (§1–§5) last reviewed: 2026-07-14
- Stack versions last verified: 2026-07-14
- AI-native tool references last verified: 2026-07-14

Refresh (`/10x-test-plan --refresh`) when:

- a new top-3 risk surfaces from the roadmap or archive,
- a recommended tool's `checked:` date is older than three months,
- the project's tech stack changes (new framework, new test runner),
- §7 negative-space no longer matches what the team believes.
