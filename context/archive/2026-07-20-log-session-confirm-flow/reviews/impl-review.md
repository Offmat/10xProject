<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Log Session with Confirm Flow

- **Plan**: context/changes/log-session-confirm-flow/plan.md
- **Scope**: Phases 1–3 of 3 (full plan)
- **Date**: 2026-07-26
- **Verdict**: REJECTED
- **Findings**: 1 critical 6 warnings 2 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | FAIL |
| Scope Discipline | WARNING |
| Safety & Quality | FAIL |
| Architecture | PASS |
| Pattern Consistency | WARNING |
| Success Criteria | WARNING |

## Findings

### F1 — Guest participants wiped on session edit

- **Severity**: ❌ CRITICAL
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/views/game_sessions/_form.html.erb:29
- **Detail**: Edit form loads other players with `game_session_participants.where.not(user: current_user)`. In SQL that is `user_id != ?`, which excludes `user_id IS NULL`, so guest rows never render. `GameSessions::Update#remove_missing_participants` then destroys any non-logger participant absent from submitted IDs (`update.rb:68-69`). Editing a session that has guests (even to change only a friend's score) deletes those guests. Service already has the correct NULL-safe scope in `non_logger_participants` (`user_id != ? OR user_id IS NULL`) but the form does not use it. Specs never cover create-with-guest → edit → guest still present.
- **Fix**: Load edit rows with the same NULL-safe non-logger scope (prefer assigning `@player_rows` in the controller). Add a request/service example that asserts guests survive an edit that does not change them.
- **Decision**: FIXED — user applied NULL-safe scope; F6 moved load to controller + request specs.

### F2 — `played_at` omitted end-to-end

- **Severity**: ⚠️ WARNING
- **Impact**: 🔬 HIGH — architectural stakes; think carefully before deciding
- **Dimension**: Plan Adherence
- **Location**: db/migrate/20260724164158_create_game_sessions.rb:3-8
- **Detail**: Plan required `played_at` (NOT NULL) on `game_sessions`, set to `Time.current` on create, validated on the model, shown in index/show/notifications, and reserved for S-04 filtering. Implementation has no column; Create never sets it; views use `created_at` instead (`index.html.erb:20`, `show.html.erb:8`). Migration Notes explicitly called this out as intentional future surface.
- **Fix A ⭐ Recommended**: Add `played_at` via migration (backfill from `created_at`), set it in Create, show it in views, restore factory/model coverage — matches plan and unblocks S-04.
  - Strength: Restores planned contract; `created_at` is a poor stand-in once played-date UI exists.
  - Tradeoff: Small schema + service + view touch across already-shipped tables.
  - Confidence: HIGH — plan and Migration Notes are explicit.
  - Blind spot: Whether any external consumer already assumes `created_at` as played time (unlikely pre-launch).
- **Fix B**: Document intentional deferral in the plan (use `created_at` until S-04) and drop `played_at` from this slice's contract.
  - Strength: Avoids churn if S-04 will redesign the column anyway.
  - Tradeoff: Leaves a known plan lie; S-04 must rediscover the gap.
  - Confidence: MEDIUM — depends on roadmap timing for played-date.
  - Blind spot: Downstream slices that already cite `played_at` in the PRD/roadmap.
- **Decision**: FIXED via Fix B — plan addendum documents `played_at` deferred to S-04; UI uses `created_at`.

### F3 — Unplanned `notifications.reason` column and copy

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Scope Discipline
- **Location**: db/migrate/20260726184117_add_reason_to_notifications.rb:3
- **Detail**: Phase 3 added `reason` (NOT NULL, default `invitation`), model `REASONS` validation, Update service branches (`update` / `update_after_rejection`), and reason-specific inbox copy. None of this is in the plan's Notification contract. Useful UX, but unplanned schema + API surface.
- **Fix A ⭐ Recommended**: Keep the feature; document it as a plan addendum (reasons + when Update sets them).
  - Strength: Preserves shipped UX; updates ground truth for archive/reviews.
  - Tradeoff: Plan becomes slightly post-hoc.
  - Confidence: HIGH — addendum pattern used elsewhere in this repo.
  - Blind spot: Specs barely cover reason values/branches.
- **Fix B**: Remove `reason` and revert to plan-shaped notifications (single invitation copy).
  - Strength: Strict scope discipline.
  - Tradeoff: Loses clearer re-notify messaging; migration rollback needed.
  - Confidence: MEDIUM — depends whether anyone already relies on the copy.
  - Blind spot: Whether reject→re-notify UX needs the distinct reason.
- **Decision**: FIXED via Fix A — plan addendum documents `notifications.reason` and Update/inbox usage.

### F4 — Confirm/reject ignore unread and terminal participant state

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: app/controllers/notifications_controller.rb:8-19
- **Detail**: Actions use `Notification.for_user(current_user).find` — not `unread`, not pending-only. A known notification ID can re-`confirm!` / `reject!` after the inbox item is gone, enabling undo against plan “What We’re NOT Doing → Revocation”. Friendships scope accept/decline to `Friendship.incoming_to` (pending only) so already-handled IDs 404.
- **Fix**: Scope like friendships — e.g. `Notification.unread.for_user(current_user).find(...)` and/or only transition when `notifiable.pending?`. Spec: acting on a read notification returns 404 and leaves status unchanged.
- **Decision**: FIXED — `find_actionable_notification` requires unread + pending; request specs cover read → 404.

### F5 — Game change skips submitted score / guest updates

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: app/services/game_sessions/update.rb:59-63
- **Detail**: When `game_changed`, `sync_participants` calls `reset_all_registered_participants` (status + notify only) and skips `update_existing_participants`. Score and guest field changes in the same submit are dropped; only game id + logger score + add/remove apply.
- **Fix**: Always run per-player field sync (scores/guest names), then reset registered non-logger statuses when the game changes (or apply submitted attributes inside the reset path).
- **Decision**: FIXED — game-change path calls `apply_submitted_fields` before reset; unit spec covers score + guest in same submit.

### F6 — Database queries in the session form partial

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: app/views/game_sessions/_form.html.erb:19,29
- **Detail**: View runs `find_by(user: current_user)` for creator score and a relation query for player rows. `app/AGENTS.md` Views convention: do not query the DB from views; controllers own data loading. Same bug surface as F1 (wrong scope chosen in the view).
- **Fix**: Assign `@creator_score` and `@player_rows` (NULL-safe) in `GameSessionsController` form-loading path; render ivars only.
- **Decision**: FIXED — `load_form_data` sets `@creator_score` / `@player_rows`; form renders ivars only; request specs cover guest on edit + keep on update.

### F7 — N+1 on notification session creator

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/controllers/notifications_controller.rb:3-5
- **Detail**: Index includes `notifiable: { game_session: :game }` but the inbox reads `game_session.creator.email` without `:creator` → one query per notification card.
- **Fix**: `.includes(notifiable: { game_session: [:game, :creator] })`.
- **Decision**: FIXED — index includes `:creator` on `game_session`.

### F8 — Create unit spec omits `:invalid` branch

- **Severity**: ⚪ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Adherence
- **Location**: spec/services/unit/game_sessions/create_spec.rb
- **Detail**: Phase 2 contract required covering `:invalid` (bad data). Unit create spec covers `:created`, `:game_not_found`, `:not_friends` but has no `:invalid` example.
- **Fix**: Add an example that forces RecordInvalid (e.g. blank score) and expects `:invalid`.
- **Decision**: FIXED — create unit spec covers nil `creator_score` → `:invalid`.

### F9 — Manual Progress checks stamped without guest-edit evidence

- **Severity**: ⚪ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Success Criteria
- **Location**: context/changes/log-session-confirm-flow/plan.md:536-543
- **Detail**: Manual items 3.5–3.12 are all `[x]` with the same commit as Phase 3 automation (`995d779`). Automated suite passes (`bin/rspec` 190 examples, `bin/rubocop`, `bin/ci`), but F1 would fail a real “session with guest → edit” path — so claimed manual coverage for mixed-player edit flows is incomplete or was not exercised.
- **Fix**: Re-run manual edit-with-guest after F1 is fixed; keep Progress stamps accurate to what was actually exercised.
- **Decision**: FIXED — Progress note documents guest-edit gap; covered by new request specs after F1/F6.
