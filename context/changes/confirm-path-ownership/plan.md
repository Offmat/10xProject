# Confirm Path & Ownership Implementation Plan

## Overview

Harden request-spec oracles for test-plan §3 Phase 2 (Risks #3–#4): prove confirm/reject steers co-player history inclusion, and prove foreign-id mutations return 404 with the target resource unchanged. Align friendship IDOR examples to the same unchanged-oracle contract (minimal delta). Fill cookbook §6.5 (plus light §6.1–§6.2 / §6.6 notes). Change product code only if a new oracle fails on current main.

## Current State Analysis

- Confirm/reject HTTP path: `NotificationsController` — scoped `unread.for_user` + `notifiable.pending?` → else 404; then `confirm!`/`reject!` + `mark_as_read!` (`app/controllers/notifications_controller.rb`).
- History inclusion: single scope `GameSession.visible_to` — logger via `creator`, co-player only if `GameSessionParticipant.confirmed` (`app/models/game_session.rb:6-11`). No dedicated stats feature yet (S-04); `GET /game_sessions` is the Risk #3 surface.
- Existing request coverage asserts confirm/reject status + foreign-id **404**, and session non-creator **404**, but often omits **resource unchanged**. No request example ties PATCH confirm/reject → friend’s index body.
- Friendships already assert 404 + status/existence unchanged (`spec/requests/friendships_spec.rb`); this change keeps that contract and bumps notification/session (and friendships if needed) to one shared IDOR oracle style documented in the cookbook.
- Cookbook §6.1, §6.2, §6.5 still TBD in `context/foundation/test-plan.md`.

### Key Discoveries:

- Product defense for Risks #3–#4 is largely already implemented via scoped finds → 404
- Phase 2 gap is oracle strength + cookbook, not greenfield auth
- Friendships IDOR examples are in-scope for a minimal align/strengthen pass (same change_id)
- `User#game_session_participations` is unscoped — cookbook must warn S-04 to reuse `visible_to`

## Desired End State

- Request specs prove: after friend confirms → session appears on friend’s `GET /game_sessions`; after reject → does not; while pending → does not; after friend rejects → logger’s index still includes the session
- Request specs prove: foreign notification confirm/reject and non-creator session update → 404 **and** target fields unchanged; friendship foreign-id examples share the same documented contract
- `test-plan.md` §6.5 filled; §6.1–§6.2 / §6.6 note Phase 2 patterns and that friendship IDOR oracles were updated here; §3 Phase 2 row status advanced when work lands
- `bin/rspec` green for touched specs; no `app/` change unless an oracle exposed a real bug

## What We're NOT Doing

- Introducing Pundit/CanCan or switching IDOR failures from 404 to 403
- Building S-04 stats UI or aggregates
- System/Capybara specs (Phase 1 / 4 of the test-plan)
- Edit re-notify matrix (test-plan §3 Phase 3 / Risk #5)
- Revocation after confirm, session destroy, unfriend cascade
- Broad friendship feature work beyond IDOR oracle alignment

## Implementation Approach

Test-first at the request layer: extend `notifications_spec` and `game_sessions_spec` for Risk #3 history oracles; tighten Risk #4 unchanged assertions there and in `friendships_spec` to one contract; document that contract in foundation cookbook (and mark Phase 2 progress in the test-plan table). If a new example fails against current main, stop and fix the minimal `app/` bug — do not weaken the oracle.

## Phase 1: Risk #3 history oracles

### Overview

Add request examples that prove confirm/reject (and pending) change what the co-player and logger see on `GET /game_sessions`, challenging “notification opened ⇒ history already updated.”

### Changes Required:

#### 1. Notification confirm/reject → friend history

**File**: `spec/requests/notifications_spec.rb`

**Intent**: After a successful confirm, the recipient’s session index includes the game; after reject, it does not. Assert via HTTP (`GET /game_sessions` as that user), not only `visible_to` in Ruby.

**Contract**: Examples under existing `PATCH .../confirm` and `PATCH .../reject` describes (or a nested context). Setup: logger creates session with pending friend participant + unread notification; act; sign in as friend; `get game_sessions_path`; body include/exclude game name (same style as existing index privacy examples in `game_sessions_spec`).

#### 2. Pending exclusion + logger after reject

**File**: `spec/requests/game_sessions_spec.rb` (and/or `notifications_spec.rb` if the reject flow already signs users there)

**Intent**: Pending tagged friend never sees the session on index; after friend rejects, logger still sees it on their index.

**Contract**: At least one pending-friend index exclusion example and one logger-still-listed-after-reject example at request layer. Prefer distinct game names if multiple sessions exist in the example to avoid false positives.

### Success Criteria:

#### Automated Verification:

- New history-oracle examples pass: `bin/rspec spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb`
- RuboCop clean on touched specs: `bin/rubocop spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb`

#### Manual Verification:

- None (request-layer only)

---

## Phase 2: Risk #4 unchanged oracles (sessions, notifications, friendships)

### Overview

Every foreign-id mutation covered here returns 404 **and** leaves the target resource in its pre-request state. Notifications and game sessions get the missing unchanged asserts; friendships stay aligned to the same contract (minimal edits only).

### Changes Required:

#### 1. Foreign notification confirm/reject unchanged

**File**: `spec/requests/notifications_spec.rb`

**Intent**: Extend the two existing foreign-id examples so they assert participant status and notification `read_at` (and pending-ness) unchanged after the 404 — not status alone.

**Contract**: Same examples at confirm L62–70 and reject L102–110 today; add reload expectations for participant status (still pending) and `notification.read_at` still nil. Do not remove the 404 assertion.

#### 2. Non-creator session update unchanged

**File**: `spec/requests/game_sessions_spec.rb`

**Intent**: Non-creator `PATCH` already expects 404; also assert key session/participant attributes unchanged (e.g. `game_id`, creator score) after the attempt.

**Contract**: Extend the example around L226–235. Capture attributes before the request; after 404, `reload` and compare. Params may attempt a visible mutation (score/game) so “unchanged” is meaningful.

#### 3. Friendship IDOR oracle alignment

**File**: `spec/requests/friendships_spec.rb`

**Intent**: Keep or minimally tighten foreign accept/decline/cancel examples so they match the documented Phase 2 IDOR contract (404 + resource unchanged). If notification/session oracles introduce a clearer assertion style, mirror it here — no broader friendship feature work.

**Contract**: Existing examples L66–74, L89–97, L112–120 already assert pending/existence; adjust only if needed for consistency with the cookbook wording (e.g. explicit attribute checks). Do not expand into new friendship behaviors.

### Success Criteria:

#### Automated Verification:

- Touched request specs pass: `bin/rspec spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb spec/requests/friendships_spec.rb`
- RuboCop clean on those files: `bin/rubocop spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb spec/requests/friendships_spec.rb`
- If any new oracle fails on current main: minimal `app/` fix + specs green (pause and note in Progress); do not weaken oracles

#### Manual Verification:

- None (request-layer only)

---

## Phase 3: Cookbook + foundation notes

### Overview

Replace TBD cookbook slots for Phase 2 patterns; record that friendship IDOR oracles were updated in this change; advance the test-plan §3 Phase 2 status when Phase 1–2 are done.

### Changes Required:

#### 1. Fill confirm/ownership cookbook

**File**: `context/foundation/test-plan.md`

**Intent**: Replace §6.5 TBD with concrete how-to: Risk #3 history oracles (PATCH confirm/reject then friend’s `GET /game_sessions`; pending exclude; logger after reject) and Risk #4 IDOR (scoped find → 404 + assert target unchanged). Include short note: reuse `GameSession.visible_to` for future stats; do not aggregate `user.game_session_participations` without `.confirmed` + creator OR.

**Contract**: Heading `### 6.5 Adding a test for confirm/reject or notification ownership` stays. Point at canonical examples in `spec/requests/notifications_spec.rb`, `game_sessions_spec.rb`, and `friendships_spec.rb`. **Run locally:** `bin/rspec`.

#### 2. Light §6.1 / §6.2 / §6.6 + Phase 2 status

**File**: `context/foundation/test-plan.md`

**Intent**: Point §6.1–§6.2 at Phase 2 examples / `spec/AGENTS.md` instead of pure TBD where Phase 2 owns the pattern; in §6.6 note this change_id updated friendship IDOR oracles alongside notification/session. When Phases 1–2 are complete, set §3 table Phase 2 Status + Change folder to this change.

**Contract**: Do not invent system-spec cookbook (§6.3–§6.4 remain Phase 1/4). Status values follow the test-plan’s left-to-right convention; folder `context/changes/confirm-path-ownership/`.

#### 3. Spec guidelines pointer (optional one-liner)

**File**: `spec/AGENTS.md`

**Intent**: One short convention line under request/integration guidance: IDOR request examples assert HTTP failure **and** target unchanged; see test-plan §6.5.

**Contract**: Additive only; do not rewrite auth helpers section.

### Success Criteria:

#### Automated Verification:

- Cookbook sections exist and no longer read TBD for §6.5: inspect `context/foundation/test-plan.md`
- Full relevant suite still green: `bin/rspec spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb spec/requests/friendships_spec.rb`

#### Manual Verification:

- Skim §6.5: a new contributor could copy the confirm↔history and IDOR unchanged pattern without reading the research doc
- Confirm §3 Phase 2 row points at `confirm-path-ownership` once implementation finishes

---

## Testing Strategy

### Unit Tests:

- No new model-only matrix required; existing `game_session_spec` `visible_to` coverage stays as unit backup

### Integration Tests:

- Existing `spec/services/integration/game_sessions_spec.rb` lifecycle remains; do not duplicate unless a gap appears after request oracles land

### Request Tests (primary):

- Risk #3: confirm/reject/pending/logger history via `GET /game_sessions`
- Risk #4: foreign notification confirm/reject + non-creator session update + friendship foreign-id — 404 + unchanged

### Manual Testing Steps:

1. None required for ship; optional smoke: log session as A tagging B → B confirm → B index shows game; B reject path excludes; A still sees after B rejects

## Performance Considerations

None — request specs only; no new queries in production paths unless a bugfix forces a minimal `app/` fix.

## Migration Notes

None.

## References

- Related research: `context/changes/confirm-path-ownership/research.md`
- Test plan Risks #3–#4 / §3 Phase 2: `context/foundation/test-plan.md`
- Baseline IDOR examples: `spec/requests/friendships_spec.rb:66-120`
- Confirm HTTP: `app/controllers/notifications_controller.rb:8-28`
- Visibility: `app/models/game_session.rb:6-11`
- Prior confirm flow: `context/changes/log-session-confirm-flow/`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Risk #3 history oracles

#### Automated

- [x] 1.1 New history-oracle examples pass: `bin/rspec spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb` — b9fc0ad
- [x] 1.2 RuboCop clean on touched specs: `bin/rubocop spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb` — b9fc0ad

### Phase 2: Risk #4 unchanged oracles (sessions, notifications, friendships)

#### Automated

- [x] 2.1 Touched request specs pass: `bin/rspec spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb spec/requests/friendships_spec.rb`
- [x] 2.2 RuboCop clean on those files: `bin/rubocop spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb spec/requests/friendships_spec.rb`
- [x] 2.3 If any new oracle fails on current main: minimal `app/` fix + specs green (pause and note in Progress); do not weaken oracles

### Phase 3: Cookbook + foundation notes

#### Automated

- [ ] 3.1 Cookbook sections exist and no longer read TBD for §6.5: inspect `context/foundation/test-plan.md`
- [ ] 3.2 Full relevant suite still green: `bin/rspec spec/requests/notifications_spec.rb spec/requests/game_sessions_spec.rb spec/requests/friendships_spec.rb`

#### Manual

- [ ] 3.3 Skim §6.5: a new contributor could copy the confirm↔history and IDOR unchanged pattern without reading the research doc
- [ ] 3.4 Confirm §3 Phase 2 row points at `confirm-path-ownership` once implementation finishes
