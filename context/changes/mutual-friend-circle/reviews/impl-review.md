<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Mutual Friend Circle (S-02)

- **Plan**: context/changes/mutual-friend-circle/plan.md
- **Scope**: Phases 1–3 of 3 (full plan)
- **Date**: 2026-07-20
- **Verdict**: NEEDS ATTENTION
- **Findings**: 0 critical 3 warnings 4 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | WARNING |
| Scope Discipline | PASS |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

## Findings

### F1 — N+1 on friends index association emails

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/controllers/friendships_controller.rb:3-5 (manifest in app/views/friendships/index.html.erb:47,68)
- **Detail**: `@incoming` / `@outgoing` load friendship rows without `includes`. The view reads `friendship.requester.email` and `friendship.addressee.email` per row → N+1 queries.
- **Fix**: Prefetch associations: `Friendship.incoming_to(current_user).includes(:requester)` and `Friendship.outgoing_from(current_user).includes(:addressee)`.
- **Decision**: FIXED

### F2 — Concurrent same-direction create can 500 on unique index

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: app/services/friendships/create_request.rb:37
- **Detail**: Two concurrent A→B requests can both miss `find_by` and race into `create!`, raising unrescued `ActiveRecord::RecordNotUnique` (500). Specs do not cover this path. Plan focused on reciprocal concurrency, not same-direction double-submit.
- **Fix A ⭐ Recommended**: Rescue `RecordNotUnique`, re-load the forward row, return `:already_requested` (or re-enter branch logic).
  - Strength: Small change; matches unique-index reality; no UX 500.
  - Tradeoff: Rare race still needs careful retry semantics.
  - Confidence: HIGH — standard Rails unique-index race pattern.
  - Blind spot: Exact flash/UX for the losing request.
- **Fix B**: Rely on DB uniqueness only and map 500→generic error in controller.
  - Strength: Less service complexity.
  - Tradeoff: Worse UX; hides domain outcome.
  - Confidence: LOW — poorer fit for this API.
  - Blind spot: Client retry behavior.
- **Decision**: FIXED — UI guard via `data-turbo_submits_with` (addressed double-click genesis; Turbo already disables submitter; two-tab race accepted for MVP)

### F3 — Reciprocal concurrency reconcile incomplete under READ COMMITTED

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: app/services/friendships/create_request.rb:19-39,46-55
- **Detail**: Plan Critical Implementation Details require transaction + post-insert reverse re-check. Both exist, but under Postgres READ COMMITTED overlapping A→B and B→A transactions often cannot see each other’s uncommitted inserts, so both can commit pending and `reconcile_concurrent_reverse!` never fires — leaving dual pending rows (stale outgoing after one accept). Rare at friend-circle scale; weaker than the stated end-state guarantee.
- **Fix A ⭐ Recommended**: Accept residual risk for MVP; document in plan Open Risks that advisory locking was deferred (matches “extremely unlikely at friend-circle scale”).
  - Strength: Honest about guarantee; no premature complexity.
  - Tradeoff: Dual-pending edge case remains.
  - Confidence: HIGH — plan already framed this as extreme edge.
  - Blind spot: Whether product later needs hard guarantee before S-03.
- **Fix B**: Serialize unordered pair with `pg_advisory_xact_lock` on sorted user ids inside the transaction; keep reconcile as backstop.
  - Strength: Makes reciprocal auto-accept guarantee honest under concurrency.
  - Tradeoff: Postgres-specific; more code to test.
  - Confidence: MEDIUM — correct approach, overkill for MVP volume.
  - Blind spot: Lock contention under load (unlikely here).
- **Decision**: FIXED via Fix A — residual risk documented in plan Open Risks; advisory locking deferred for MVP

### F4 — Scope and service API naming diverge from plan text

- **Severity**: ⚪ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Adherence
- **Location**: app/models/friendship.rb:9-10; app/services/friendships/create_request.rb:5
- **Detail**: Plan names `incoming_for` / `outgoing_for` and `.call(requester:, email:)`. Implementation uses `incoming_to` / `outgoing_from` and `addressee_email:` (intentional clarity renames). Behavior matches; plan text was not amended.
- **Fix**: Leave code as-is; optionally add a one-line plan addendum noting the renames.
- **Decision**: FIXED — code left as-is; plan addendum notes naming drift

### F5 — Nav badge count loaded in ApplicationController, not the layout

- **Severity**: ⚪ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Adherence
- **Location**: app/controllers/application_controller.rb:9-16; app/views/layouts/application.html.erb:32-37
- **Detail**: Plan contracted an inline `Friendship.incoming_for(current_user).count` in the layout. Implementation sets `@incoming_friend_request_count` via `before_action` and documents “no DB in views” in `app/AGENTS.md`. Same product behavior; better layering.
- **Fix**: Treat as accepted improvement; no code change.
- **Decision**: FIXED — accepted improvement; no code change

### F6 — Unbounded friends / request lists on index

- **Severity**: ⚪ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/controllers/friendships_controller.rb:2-5
- **Detail**: Index loads all friends, incoming, and outgoing with no limit. Acceptable for MVP friend-circle scale (`prd.md` target_scale).
- **Fix**: Defer pagination until needed.
- **Decision**: FIXED — deferred pagination until needed; no code change

### F7 — Self-friend invariant is app-level only

- **Severity**: ⚪ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/models/friendship.rb:32-36; db/migrate/20260715150000_create_friendships.rb
- **Detail**: `cannot_friend_self` validation has no matching DB `CHECK (requester_id <> addressee_id)`. Raw SQL could insert a self-row.
- **Fix**: Optional follow-up migration adding a CHECK constraint.
- **Decision**: FIXED — added `friendships_requester_ne_addressee` CHECK constraint migration

## Success criteria verification

### Automated (re-run 2026-07-20)

| Check | Result |
|-------|--------|
| `bin/rspec` friendship model + request + create_request specs | PASS — 36 examples, 0 failures |
| `bin/rubocop` on touched Ruby files | PASS — no offenses |
| `bin/brakeman` | PASS — 0 warnings |

### Manual (Progress)

All Manual Progress rows `[x]` (1.4, 2.5–2.6, 3.3–3.7). User confirmed browser flows and IDOR 404 during implementation; no rubber-stamp flags beyond normal manual attestation.
