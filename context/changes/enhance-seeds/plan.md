# Enrich Seeds Implementation Plan

## Overview

Expand `db/seeds.rb` so a fresh or re-run seed gives a useful local demo: four shared-password users (including Carol), an Alice-hub mix of accepted and pending friendships, and several Alice-created game sessions covering signed friends, guests, and solo play.

## Current State Analysis

- `db/seeds.rb` seeds three users (`alice@example.com`, `bob@example.com`, `alex@example.com`) with a local `seed_password = 'Qwertyuiop'` and upserts games from `db/seeds/games.yml`.
- No friendships or game sessions are seeded.
- Friendships are directed (`requester` / `addressee`) with `pending` / `accepted` / `declined`; uniqueness is per directed pair. Specs create rows directly; `Friendships::CreateRequest` is the email/UX path and is a poor fit for seeds.
- Game sessions must be created via `GameSessions::Create` so logger participants, friendship checks, guest XOR identity, and notifications match production. Friend co-players require an **accepted** friendship. Create leaves friend participants `pending` and inserts a `Notification`; `GameSessionParticipant#confirm!` is how friends become visible via `GameSession.visible_to`.
- Session time is `created_at` only — there is no `played_at` / winner field.

## Desired End State

After `bin/rails db:seed` (or `bin/setup`):

1. Four users exist with the shared password constant value `Qwertyuiop`: alice, bob, alex, **carol@example.com**.
2. Friendships: Alice↔Bob and Alice↔Alex **accepted**; Carol→Alice **pending** (Alice has an incoming request).
3. Alice has multiple created sessions covering: solo, guest player(s), different signed friends, and at least one mixed friend+guest case.
4. Most friend co-players in those sessions are **confirmed**; exactly one friend participation remains **pending** (confirm UX + notification).
5. Re-running seed is deterministic for this demo graph: friendships among the four users and Alice-created sessions are wiped, then recreated (users/games stay upsert-style).

### Key Discoveries:

- User upsert already uses `find_or_create_by!(email:)` with password only on create (`db/seeds.rb:11-22`).
- Prefer `Friendship` rows with explicit `status` over `Friendships::CreateRequest` for seeds.
- Prefer `GameSessions::Create.call(creator:, game_id:, creator_score:, players:)` (`app/services/game_sessions/create.rb`); assert `:created` or raise so seed failures are loud.
- Destroying `GameSession` cascades participants; participant destroy cascades notifications (`app/models/game_session.rb`, `game_session_participant.rb`).

## What We're NOT Doing

- Changing the shared password value away from `Qwertyuiop`.
- Seeding declined friendships or reverse duplicate edges.
- Adding schema fields (`played_at`, winners, etc.).
- Using factories inside seeds.
- Automated seed/CI specs for the inventory (manual checklist only).
- Touching `db/seeds/games.yml` / Wikidata import beyond selecting existing games for sessions.
- Seeding sessions created by non-Alice users.

## Implementation Approach

Keep enrichment in the seed entrypoint (inline in `db/seeds.rb`, or thin `require_relative` helpers under `db/seeds/` if readability suffers). Order: upsert users → upsert games (existing) → wipe demo friendships/sessions for the seed cohort → recreate friendships → recreate Alice sessions via `GameSessions::Create` → selectively `confirm!` friend participants (leave one pending).

## Critical Implementation Details

### Timing & lifecycle

Wipe **before** recreate, and wipe sessions **before** friendships only if needed for clarity — actually destroy Alice-created sessions first (cleans participants/notifications), then destroy friendships among the four seed users, then recreate friendships, then sessions (Create requires accepted friends). Do not wipe `Game` rows or non-seed users.

### State sequencing

After Create, friend participants are `pending`. Confirm all but one targeted friend participation so Bob/Alex can see most shared history while one pending row still demos confirm/reject.

---

## Phase 1: Users & friendships

### Overview

Introduce a named password constant, add Carol, and wipe/recreate the Alice-hub friendship graph.

### Changes Required:

#### 1. Seed users

**File**: `db/seeds.rb`

**Intent**: Replace the local password variable with a named constant (same value `Qwertyuiop`), keep alice/bob/alex, add `carol@example.com`, and fix the user `puts` line so it lists all four.

**Contract**: All four emails use `User.find_or_create_by!(email:)` with password/password_confirmation set only in the create block. Constant name is seed-local (e.g. `SEED_PASSWORD`) — not an app config credential.

#### 2. Wipe + seed friendships

**File**: `db/seeds.rb` (or `db/seeds/friendships.rb` required from it)

**Intent**: On each seed run, remove friendships among the four seed users, then create the Alice-hub graph so accepted + pending states are both visible when signed in as Alice (and Carol’s outgoing pending is visible to her).

**Contract**:
- Wipe: destroy `Friendship` rows where both endpoints are in the seed-user set (or either endpoint is in the set — prefer “involving any seed user” only if simpler; must not leave stale Alice↔Bob rows).
- Recreate exactly:
  - accepted: Alice ↔ Bob (either direction)
  - accepted: Alice ↔ Alex
  - pending: Carol → Alice (`requester: carol`, `addressee: alice`)
- Do **not** call `Friendships::CreateRequest`.
- Idempotent outcome via wipe-then-create, not find-or-create on status.

### Success Criteria:

#### Automated Verification:

- `bin/rails db:seed` exits 0
- Console/query check: four users by email; three friendships with the statuses above

#### Manual Verification:

- Sign in as Alice — see Bob and Alex as friends; see Carol’s incoming pending request
- Sign in as Carol — see outgoing pending request to Alice

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase. Phase blocks use plain bullets — the corresponding `- [ ]` checkboxes for these items live in the `## Progress` section at the bottom of the plan.

---

## Phase 2: Alice game sessions

### Overview

Wipe Alice-created sessions and seed a small Alice-centric set covering solo, guests, and signed friends, with mixed confirmation.

### Changes Required:

#### 1. Wipe Alice demo sessions

**File**: `db/seeds.rb` (or `db/seeds/game_sessions.rb`)

**Intent**: Before recreating, destroy all `GameSession` rows where `creator` is Alice so re-seeds do not accumulate duplicates. Rely on association `dependent: :destroy` for participants and their notifications.

**Contract**: Scope wipe to Alice as creator only. Run this wipe after users exist and before (or after) friendship wipe — but **session recreate must run after accepted friendships exist**.

#### 2. Seed Alice session inventory

**File**: `db/seeds.rb` (or `db/seeds/game_sessions.rb`)

**Intent**: Create multiple Alice sessions via `GameSessions::Create` using games already present from `games.yml`, with integer scores, covering the demo matrix below. After create, auto-confirm friend participants except one designated pending case.

**Contract**:
- Call `GameSessions::Create.call(...)`; if `status != :created`, raise with a clear message (fail the seed).
- Minimum inventory (names/scores/games flexible):
  - ≥1 **solo** (`players: []`)
  - ≥1 **guests only** (one or more `type: 'guest'`)
  - ≥1 session with **Bob** as friend
  - ≥1 session with **Alex** as friend (different signed user than Bob-only)
  - ≥1 session that includes a **guest** alongside a friend (or guests + friends)
  - Exactly **one** friend participation across the inventory left `pending`; all other seeded friend participations `confirm!`’d
- Guest names should not collide confusingly with seed emails (avoid `Carol` as a guest label if it muddies the UI — e.g. use `Dana` / `Sam`).
- Do not invent `played_at` / winner attributes.
- `puts` a short summary of sessions created (count is enough).

### Success Criteria:

#### Automated Verification:

- `bin/rails db:seed` exits 0 when run twice in a row (deterministic wipe/recreate; no duplicate Alice sessions beyond the inventory)
- Query check: Alice `created_game_sessions` count matches inventory; one pending friend participant remains; others confirmed

#### Manual Verification:

- Sign in as Alice — session list shows solo, guest, and multi-player variety
- Sign in as the friend on a confirmed session — session is visible
- Sign in as the friend on the pending session — notification / confirm affordance is present

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human before treating the change as done.

---

## Testing Strategy

### Unit Tests:

- None for seed inventory (out of scope).

### Integration Tests:

- None; rely on existing `GameSessions::Create` and friendship specs already covering the APIs seeds call.

### Manual Testing Steps:

1. `bin/rails db:seed` (twice) — second run stays clean.
2. Log in as `alice@example.com` / `Qwertyuiop` — friends, pending request from Carol, varied sessions.
3. Log in as `carol@example.com` — outgoing pending to Alice.
4. Log in as Bob or Alex — see confirmed shared sessions; see pending confirm on the designated session.

## Performance Considerations

Negligible — tiny record counts. Wipe scoped to seed cohort / Alice-created sessions only.

## Migration Notes

No schema migrations. Local DBs that already have ad-hoc Alice sessions will lose those Alice-created rows on next seed (intentional wipe). Other users’ data is untouched.

## References

- Change notes: `context/changes/enhance-seeds/change.md`
- Current seeds: `db/seeds.rb`
- `GameSessions::Create`: `app/services/game_sessions/create.rb`
- Friendship model: `app/models/friendship.rb`
- Create service examples: `spec/services/unit/game_sessions/create_spec.rb`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Users & friendships

#### Automated

- [x] 1.1 `bin/rails db:seed` exits 0 — ba32a71
- [x] 1.2 Console/query check: four users by email; three friendships with the statuses above — ba32a71

#### Manual

- [x] 1.3 Sign in as Alice — see Bob and Alex as friends; see Carol’s incoming pending request — ba32a71
- [x] 1.4 Sign in as Carol — see outgoing pending request to Alice — ba32a71

### Phase 2: Alice game sessions

#### Automated

- [x] 2.1 `bin/rails db:seed` exits 0 when run twice in a row (deterministic wipe/recreate; no duplicate Alice sessions beyond the inventory)
- [x] 2.2 Query check: Alice `created_game_sessions` count matches inventory; one pending friend participant remains; others confirmed

#### Manual

- [x] 2.3 Sign in as Alice — session list shows solo, guest, and multi-player variety
- [x] 2.4 Sign in as the friend on a confirmed session — session is visible
- [x] 2.5 Sign in as the friend on the pending session — notification / confirm affordance is present
