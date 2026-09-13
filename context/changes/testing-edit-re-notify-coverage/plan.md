# Edit Re-notify Coverage Implementation Plan

## Overview

Close test-plan §3 Phase 3 (Risk #5): prove score-only edits re-notify selectively and game changes bulk-renotify, with who/why oracles (recipient, reason, pending, old notification gone / new unread) — not bare notify counts. Opportunistically cover Risk #6 with one pending-friendship create-path unit example. Fill cookbook §6.2 + §6.6. Prefer tests-only; if a new oracle fails and the oracle is independently right (risk/PRD-shaped, not lifted from `Update`), apply a minimal `app/` fix — stop and ask if the failure is ambiguous.

## Current State Analysis

- Edit classification and fan-out live only in `GameSessions::Update` (`app/services/game_sessions/update.rb`): `game_changed = game_session.game_id != game.id` → bulk `reset_all_registered_participants`; else per-friend score diff → selective destroy+create notify. Logger score and guest edits do not re-notify.
- Re-notify never updates in place: `participant.notifications.destroy_all` then `Notification.create!(..., reason:)` with `update` or `update_after_rejection` when the participant was rejected.
- Unit `spec/services/unit/game_sessions/update_spec.rb` covers single-friend score/game paths and often asserts `Notification.count` / recipient count without multi-friend contrast, without `reason`, and without rejected → `update_after_rejection`.
- Request `PATCH /game_sessions/:id` examples assert participant-set persistence and non-creator 404+unchanged — zero re-notify who/why.
- Integration lifecycle (`spec/services/integration/game_sessions_spec.rb`) resets pending after score edit but does not assert a fresh unread notification.
- Risk #6 gate already on create via `creator.friends` (accepted only). Strangers covered at unit/integration/request; pending friendship is the cheap unasserted nuance.
- Cookbook §6.2 still says “Edit re-notify matrix: TBD — see §3 Phase 3.”

### Key Discoveries:

- Product selective/bulk behavior is already implemented; Phase 3 gap is oracle strength + cookbook (same shape as Phase 2)
- Multi-friend contrast is the load-bearing challenge to “Any edit ⇒ same notify path”
- PRD FR-005/006 cover create notify + confirm/reject, not the edit matrix — oracles come from test-plan Risk #5 response guidance + observed `Update` contract
- `Notification` factory has no `reason` trait; set `reason:` / `read_at:` inline when needed

## Desired End State

- Unit specs: with ≥2 confirmed friends, score-only change to A → A pending + new unread `reason: update` (or `update_after_rejection` when rejected); B stays confirmed with no new notification. Game change → both pending + fresh unread with correct reason. Rejected participant covered on both fan-out modes.
- Request specs: same selective vs bulk who/why after `PATCH` as the logger (form-shaped `players` hash), including old (possibly read) notification destroyed and new unread for the right recipients.
- Integration lifecycle asserts post-edit unread notification (light touch — not a second full matrix).
- One unit create example: pending friendship → `:not_friends`, no `GameSession` created.
- `test-plan.md` §6.2 documents the edit re-notify pattern; §6.6 notes Phase 3; §3 Phase 3 status → `done` when Progress is complete.
- Touched specs green under `bin/rspec`; RuboCop clean on touched files.

## What We're NOT Doing

- System/Capybara specs for edit re-notify (Phase 1/4 already own browser budget)
- Dedicated Risk #6 phase or request/system examples for pending friendship (unit only)
- Asserting inbox via `GET /notifications` after every edit (DB notification + participant status is enough)
- Full combinatorial matrix of every edit × status × reason beyond the agreed multi-friend + rejection-on-both-paths set
- Push notifications, email, or reason vocabulary redesign
- Broad factory trait work unless an example needs a tiny additive trait
- Weakening oracles to match buggy fan-out

## Implementation Approach

Test-first, layered like Phase 2: tighten unit matrix first (cheapest who/why + #6), then request HTTP oracles that exercise the controller → `Update` path, then close the integration lifecycle gap and write cookbook. Oracles must name **who** (recipient / which peer untouched) and **why** (`reason`, score-only vs game change). Bare `Notification.count` alone is insufficient for new examples.

If a new example fails: treat the oracle as authoritative when it matches Risk #5 response guidance (selective vs bulk, no silent stale inbox). Apply the smallest fix in `GameSessions::Update` (or create path for #6). If the failure looks like fixture/param-shape confusion, stop and ask before changing `app/`.

## Critical Implementation Details

**Who/why oracle (all new Risk #5 examples):** For each affected friend, assert participant `pending`, notification `recipient`, `reason`, `read_at` nil, and that a known pre-edit notification id is gone. For selective score-only, also assert the untouched peer remains `confirmed` and gains no new notification. Do not stop at global `Notification.count`.

**Submit-to-survive:** `Update` destroys any co-player omitted from `players`. “Untouched” means submitted unchanged (same id + score), not omitted. Every peer (and any guest) that must remain on the session must appear in the submitted `players` set — otherwise a destroy looks like a fan-out failure.

**Request params:** Reuse the form-shaped `players` hash (string indices) already used in `spec/requests/game_sessions_spec.rb` update examples so request oracles stay honest with Stimulus POST shape.

**Product fix policy:** Clear fan-out bugs may be fixed in this change; ambiguous failures → pause for human decision (do not silently rewrite the oracle to match code). Do not change `Notification::REASONS` or reason string literals without updating inbox copy (`app/views/notifications/index.html.erb`); prefer fan-out/status fixes only.

## Phase 1: Unit matrix (Risk #5 + opportunistic #6)

### Overview

Extend service unit coverage so selective vs bulk is proven with multi-friend contrast, `reason` (including `update_after_rejection` on both paths), and stale-inbox destroy+create. Add one pending-friendship create example for Risk #6.

### Changes Required:

#### 1. Multi-friend selective vs bulk who/why

**File**: `spec/services/unit/game_sessions/update_spec.rb`

**Intent**: With two accepted friends both confirmed on the session, prove score-only edit re-notifies only the score-changed friend; prove game change re-notifies both. Challenge “any edit ⇒ same notify path.”

**Contract**: Setup: friend A and B confirmed; optional read notification on A (and B for bulk). Always submit both A and B in `players` (omit ⇒ destroy, not “untouched”). Score-only: change A’s score, keep B’s score unchanged; assert A pending + new unread `reason: 'update'`, old A notif gone; B still confirmed, no new notif for B. Game change: both pending + each has exactly one fresh unread with `reason: 'update'` (unless rejected — see next item). Prefer explicit recipient/notifiable/`reason`/`read_at` expectations over count-only.

#### 2. Rejected → `update_after_rejection` on both fan-out modes

**File**: `spec/services/unit/game_sessions/update_spec.rb`

**Intent**: When the registered participant starts `rejected`, re-notify uses `reason: 'update_after_rejection'` for both selective score edit and bulk game change.

**Contract**: At least one selective and one bulk example (can share multi-friend fixtures or nest contexts). Assert `reason` string exactly; still assert destroy-old + new unread + pending.

#### 3. Risk #6 pending friendship on create

**File**: `spec/services/unit/game_sessions/create_spec.rb`

**Intent**: Opportunistic — tagging a user with a non-accepted (pending) friendship returns `:not_friends` and creates no session, proving the gate is accepted-friends-only (not merely “no friendship row”).

**Contract**: `create(:friendship, requester:, addressee:)` without `:accepted` (factory default pending). Call `GameSessions::Create` tagging that user as friend. Expect `:not_friends` and no `GameSession` count change. Leave existing stranger examples intact.

### Success Criteria:

#### Automated Verification:

- Unit matrix + #6 examples pass: `bin/rspec spec/services/unit/game_sessions/update_spec.rb spec/services/unit/game_sessions/create_spec.rb`
- RuboCop clean on those files: `bin/rubocop spec/services/unit/game_sessions/update_spec.rb spec/services/unit/game_sessions/create_spec.rb`

#### Manual Verification:

- None (service unit only)

---

## Phase 2: Request re-notify oracles

### Overview

Add request-layer PATCH examples that prove the same selective vs bulk who/why after the HTTP update path (controller → `GameSessions::Update`), matching Phase 2’s preference for user-visible surfaces.

### Changes Required:

#### 1. Score-only selective re-notify via PATCH

**File**: `spec/requests/game_sessions_spec.rb`

**Intent**: As the logger, PATCH a session with two friend co-players changing only one friend’s score; prove that friend is re-notified (pending, new unread, correct `reason`) and the other is not.

**Contract**: Under `describe 'PATCH /game_sessions/:id'`. Sign in as creator; accepted friendships to both friends; confirmed participants + known (preferably read) notification on the score-changed friend. Form-shaped `players` must include both participant ids (omit ⇒ destroy). After redirect success: DB assertions for who/why + stale-inbox (old id gone, new unread). Do not rely on flash alone.

#### 2. Game-change bulk re-notify via PATCH

**File**: `spec/requests/game_sessions_spec.rb`

**Intent**: PATCH with a new `game_id` re-notifies all non-logger registered co-players (pending + fresh unread + reason), not only the friend whose score also changed in the same submit.

**Contract**: Same multi-friend setup; submit new game (and keep scores or change them — bulk path must still hit both). Assert both recipients get destroy+create unread with expected `reason`. If a guest is also on the session, include them in `players` (submitted unchanged or with score/name edits); they stay `confirmed` with no notification. Do not omit a guest and call them “untouched.”

### Success Criteria:

#### Automated Verification:

- Request re-notify examples pass: `bin/rspec spec/requests/game_sessions_spec.rb`
- RuboCop clean: `bin/rubocop spec/requests/game_sessions_spec.rb`

#### Manual Verification:

- None (request-layer only)

---

## Phase 3: Integration touch + cookbook

### Overview

Close the lifecycle post-edit notification gap with a light assert; document the edit re-notify pattern in the test-plan cookbook; mark §3 Phase 3 complete when Phases 1–2 are done.

### Changes Required:

#### 1. Lifecycle post-edit notification assert

**File**: `spec/services/integration/game_sessions_spec.rb`

**Intent**: After the existing create → confirm → score-edit step, assert the friend has a fresh unread notification (who/why: recipient + preferably `reason: 'update'`), not only pending status/score. Do not duplicate the full multi-friend matrix here.

**Contract**: Extend the example under `create → confirm → edit → re-confirm` after Step 3. Prefer asserting unread for that friend + reason over a bare global count. Keep re-confirm steps.

#### 2. Fill §6.2 edit re-notify + §6.6 Phase 3 note

**File**: `context/foundation/test-plan.md`

**Intent**: Replace the §6.2 “Edit re-notify matrix: TBD” pointer with a concrete how-to (selective vs bulk, who/why, stale inbox, anti-pattern). Add a §6.6 bullet for this change_id. When Phases 1–2 are complete, set §3 Phase 3 Status to `done` and keep Change folder `testing-edit-re-notify-coverage`.

**Contract**: Pattern should cite canonical examples in `spec/services/unit/game_sessions/update_spec.rb`, `spec/requests/game_sessions_spec.rb`, and the integration lifecycle touch. Mention opportunistic #6 unit example on create. Mirror §6.5 tone (numbered steps, anti-patterns, run locally). Do not invent system-spec cookbook for this phase.

### Success Criteria:

#### Automated Verification:

- Integration + request + unit touched paths still green: `bin/rspec spec/services/integration/game_sessions_spec.rb spec/services/unit/game_sessions/update_spec.rb spec/services/unit/game_sessions/create_spec.rb spec/requests/game_sessions_spec.rb`
- Cookbook no longer TBD for edit re-notify in §6.2: inspect `context/foundation/test-plan.md`
- §3 Phase 3 row Status is `done` with Change folder `testing-edit-re-notify-coverage`

#### Manual Verification:

- Skim §6.2: a new contributor could add a selective vs bulk who/why example without reading this plan
- Confirm §3 Phase 3 row reflects completion

---

## Testing Strategy

### Unit Tests:

- Multi-friend selective vs bulk; reason including `update_after_rejection` on both paths; Risk #6 pending friendship on create

### Integration Tests:

- Light lifecycle assert after score edit (unread + reason); no second matrix

### Request Tests:

- PATCH selective and bulk who/why with form-shaped players params

### Manual Testing Steps:

1. None required for ship; optional smoke: two friends on a session → edit one score → only that friend sees a new inbox item; change game → both see new items

## Performance Considerations

None — specs only unless a minimal `Update` fix is required; no new production query paths planned.

## Migration Notes

None.

## References

- Test plan Risk #5 / §3 Phase 3: `context/foundation/test-plan.md`
- Change notes: `context/changes/testing-edit-re-notify-coverage/change.md`
- Update fan-out: `app/services/game_sessions/update.rb`
- Create friend gate: `app/services/game_sessions/create.rb`
- Unit baseline: `spec/services/unit/game_sessions/update_spec.rb`
- Request update baseline: `spec/requests/game_sessions_spec.rb`
- Integration lifecycle: `spec/services/integration/game_sessions_spec.rb`
- Phase 2 cookbook precedent: `context/archive/2026-08-02-confirm-path-ownership/plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Unit matrix (Risk #5 + opportunistic #6)

#### Automated

- [x] 1.1 Unit matrix + #6 examples pass: `bin/rspec spec/services/unit/game_sessions/update_spec.rb spec/services/unit/game_sessions/create_spec.rb` — fcfc9e5
- [x] 1.2 RuboCop clean on those files: `bin/rubocop spec/services/unit/game_sessions/update_spec.rb spec/services/unit/game_sessions/create_spec.rb` — fcfc9e5

### Phase 2: Request re-notify oracles

#### Automated

- [x] 2.1 Request re-notify examples pass: `bin/rspec spec/requests/game_sessions_spec.rb` — d443829
- [x] 2.2 RuboCop clean: `bin/rubocop spec/requests/game_sessions_spec.rb` — d443829

### Phase 3: Integration touch + cookbook

#### Automated

- [x] 3.1 Integration + request + unit touched paths still green: `bin/rspec spec/services/integration/game_sessions_spec.rb spec/services/unit/game_sessions/update_spec.rb spec/services/unit/game_sessions/create_spec.rb spec/requests/game_sessions_spec.rb`
- [x] 3.2 Cookbook no longer TBD for edit re-notify in §6.2: inspect `context/foundation/test-plan.md`
- [x] 3.3 §3 Phase 3 row Status is `done` with Change folder `testing-edit-re-notify-coverage`

#### Manual

- [x] 3.4 Skim §6.2: a new contributor could add a selective vs bulk who/why example without reading this plan
- [x] 3.5 Confirm §3 Phase 3 row reflects completion
