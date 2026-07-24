# Log Session with Confirm Flow — Implementation Plan

## Overview

S-03 delivers the project's north star: US-01 end-to-end. A logged-in user selects a game from the catalog, enters their own score, adds registered friends and/or unregistered guests (each with a score), and submits. The logger sees the session in their history immediately. Each tagged registered friend receives a polymorphic in-app notification and can confirm or reject participation from a dedicated inbox page. Guest players are stored as name + score only — no account, no notification, no confirm step.

This slice also introduces session editing: the logger can update a session after creation. Only participants whose data actually changed get re-notified (reset to pending). A game change resets all non-logger registered participants.

## Current State Analysis

Four tables exist: `users`, `sessions` (auth), `games`, `friendships`. Auth (S-01) and mutual friendships (S-02) are complete. The game catalog (F-02) has ~20 Wikidata-sourced titles. Tailwind CSS + daisyUI (F-03) provides the UI foundation.

There is **no** game-session logging, participant tracking, or notification infrastructure. The auth `Session` model occupies the `sessions` table name — game sessions need a distinct model name. Friend requests currently use derived queries for notifications (no `Notification` table); S-02 research explicitly deferred the notification architecture decision to this slice.

### Key Discoveries:

- `Session` model name is taken by auth — game sessions will use `GameSession` (`game_sessions` table): `app/models/session.rb:1`
- S-02 research recommended deferring polymorphic `Notification` until S-03 provides the second notification type: `context/archive/2026-07-14-mutual-friend-circle/research.md:138-146`
- S-02 research previewed participant shape: single table with nullable `user_id` OR `guest_name` with CHECK constraint: `context/archive/2026-07-14-mutual-friend-circle/research.md:126-134`
- Service convention: `.call` class method, `Data.define` result, pass identity explicitly: `app/services/friendships/create_request.rb:1-62`
- Authorization pattern: scope queries to `current_user`, 404 on IDOR: `app/controllers/friendships_controller.rb:17-27`
- Nav badge pattern: `before_action` sets count ivar, layout renders `indicator` + conditional badge: `app/controllers/application_controller.rb:13-17`, `app/views/layouts/application.html.erb:32-36`
- Stimulus scaffold ready but unused — this will be the first custom Stimulus controller: `app/javascript/controllers/hello_controller.js`
- No `accepts_nested_attributes_for` pattern exists — services will handle participant management directly

## Desired End State

After all three phases complete:

1. A logged-in user can navigate to "Sessions" → "New Session" and log a played game session.
2. The form offers a game picker (dropdown from catalog), a "Your score" field, and dynamic player rows (add/remove via Stimulus). Each player row toggles between Friend (dropdown of accepted friends) and Guest (free-text name), plus a score field.
3. On submit, the session appears immediately in the logger's session history at `/game_sessions`.
4. Each tagged registered friend receives a `Notification` record. The nav shows an unread notification badge.
5. From `/notifications`, the friend sees session details and can Confirm or Reject.
6. Confirmed sessions appear in the friend's session history. Rejected sessions do not.
7. The logger can edit a session. Only participants with changed data get re-notified (status reset to pending). A game change resets all non-logger registered participants.
8. Guest players are stored as name + score — no notification, no confirm step.

### Verification:

- `bin/rspec` passes with full model, service, and request spec coverage
- `bin/rubocop` passes
- `bin/ci` passes
- Manual end-to-end flow works in the browser (Phase 3)

## What We're NOT Doing

- **Real-time updates** — no WebSocket/polling; notifications appear on next page load
- **Session comments or notes** — log captures game, players, scores only
- **Played-date picker** — `played_at` defaults to creation time; no UI to override
- **Session photos or media** — text-only session records
- **Game rating or review** — no per-game ratings (PRD Non-Goal)
- **Push notifications** — in-app inbox only (PRD Non-Goal)
- **Friend-request inbox unification** — friend requests stay on `/friendships`; session confirms go to `/notifications`; unification parked (see roadmap)
- **Bulk session import** — one session at a time
- **Session deletion** — logger can edit but not delete for MVP
- **Revocation** — once confirmed, participation is permanent; no undo
- **Cascade on unfriend** — pending participations survive unfriending; no lifecycle hooks on friendship changes
- **Win/lose-only games** — scores are integer for now; future support for non-numeric outcomes tracked in roadmap Parked section

## Implementation Approach

Three phases following the established pattern: data model → business logic → controllers/views.

Phase 1 lays the schema foundation with three new tables and models. Phase 2 builds the service layer with full create/update/confirm/reject business logic and comprehensive specs. Phase 3 wires up controllers, routes, views, and the first Stimulus controller — only this phase includes manual browser testing.

The logger is always an auto-confirmed participant with a score. Minimum session size is 1 player (logger only — solo sessions are allowed). Registered co-players start as pending and must confirm. Guests are auto-confirmed (they don't use the app).

## Critical Implementation Details

### Naming collision avoidance

The auth `Session` model (`app/models/session.rb`) and `sessions` table are already in use. All game-session code uses `GameSession` / `game_sessions` to avoid ambiguity. In routes, controllers, and views, always use the `game_sessions` prefix — never bare `sessions` for game logging.

### Edit re-notification logic

When the logger edits a session, the service must diff old vs new state to determine which participants need re-notification:

- **Score changed** for a registered participant → reset that participant to `pending`, destroy old notifications for that participant, create a fresh notification.
- **New registered participant added** → create participant (pending) + notification.
- **Registered participant removed** → destroy participant row (cascades to notifications via `dependent: :destroy`).
- **Game changed** → reset ALL non-logger registered participants to `pending` + re-notify, because the game is fundamental to what they're confirming.
- **Guest changes** (add/remove/score) → no notifications; just update the data.
- **Logger's own score changed** → update in place; no re-notification (they're auto-confirmed).

---

## Phase 1: Data Model Foundation

### Overview

Create the three new tables (`game_sessions`, `game_session_participants`, `notifications`), their ActiveRecord models with validations/associations/scopes, wire associations into existing `User` and `Game` models, and add FactoryBot definitions. All verified by model specs.

### Changes Required:

#### 1. Game sessions migration

**File**: `db/migrate/YYYYMMDDHHMMSS_create_game_sessions.rb`

**Intent**: Create the core table for logged board-game sessions. Each session belongs to the user who created it (the logger) and references a game from the catalog.

**Contract**: `game_sessions` table — `creator_id` (bigint, NOT NULL, FK → users), `game_id` (bigint, NOT NULL, FK → games), `played_at` (datetime, NOT NULL), timestamps. Indexes on `creator_id` and `game_id`.

#### 2. Game session participants migration

**File**: `db/migrate/YYYYMMDDHHMMSS_create_game_session_participants.rb`

**Intent**: Store per-player data for each session in a single table that handles both registered users and named guests via a CHECK constraint.

**Contract**: `game_session_participants` table — `game_session_id` (bigint, NOT NULL, FK), `user_id` (bigint, nullable, FK → users), `guest_name` (string, nullable), `score` (integer, NOT NULL), `status` (integer, NOT NULL, default 0), timestamps. CHECK constraint: `(user_id IS NOT NULL AND guest_name IS NULL) OR (user_id IS NULL AND guest_name IS NOT NULL)`. Partial unique index on `[game_session_id, user_id]` where `user_id IS NOT NULL` (one row per registered user per session). Index on `game_session_id`.

#### 3. Notifications migration

**File**: `db/migrate/YYYYMMDDHHMMSS_create_notifications.rb`

**Intent**: Polymorphic notification table for the in-app inbox. First consumer is session-confirm notifications; designed to support additional notification types later.

**Contract**: `notifications` table — `recipient_id` (bigint, NOT NULL, FK → users), `notifiable_type` (string, NOT NULL), `notifiable_id` (bigint, NOT NULL), `read_at` (datetime, nullable), timestamps. Indexes on `[recipient_id, read_at]` and `[notifiable_type, notifiable_id]`.

#### 4. GameSession model

**File**: `app/models/game_session.rb`

**Intent**: Core domain model representing a played board-game session.

**Contract**: `belongs_to :creator, class_name: 'User'`; `belongs_to :game`; `has_many :game_session_participants, dependent: :destroy`. Validates presence of `creator`, `game`, `played_at`. Scope `created_by(user)`. Scope `visible_to(user)` — sessions where user is the creator OR has a confirmed `GameSessionParticipant` row.

#### 5. GameSessionParticipant model

**File**: `app/models/game_session_participant.rb`

**Intent**: Represents one player's participation in a session — either a registered user (with confirm/reject flow) or a named guest (auto-confirmed).

**Contract**: `belongs_to :game_session`; `belongs_to :user, optional: true`; `has_many :notifications, as: :notifiable, dependent: :destroy`. Enum `status: { pending: 0, confirmed: 1, rejected: 2 }`. Validates `score` presence and numericality (integer). Custom validation: exactly one of `user_id`/`guest_name` must be present. Uniqueness of `user_id` scoped to `game_session_id` (when present). Instance methods: `confirm!` (update status to confirmed), `reject!` (update status to rejected). Helpers: `registered?`, `guest?`, `display_name` (returns user email or guest_name).

#### 6. Notification model

**File**: `app/models/notification.rb`

**Intent**: Polymorphic in-app notification for the inbox.

**Contract**: `belongs_to :recipient, class_name: 'User'`; `belongs_to :notifiable, polymorphic: true`. Scope `unread` (where `read_at` is nil). Scope `for_user(user)` (where `recipient` is user). `mark_as_read!` sets `read_at` to current time.

#### 7. User and Game association updates

**File**: `app/models/user.rb`

**Intent**: Wire User to game sessions, participations, and notifications.

**Contract**: Add `has_many :created_game_sessions, class_name: 'GameSession', foreign_key: :creator_id, dependent: :destroy`; `has_many :game_session_participations, class_name: 'GameSessionParticipant'`; `has_many :notifications, foreign_key: :recipient_id, dependent: :destroy`.

**File**: `app/models/game.rb`

**Intent**: Wire Game to game sessions.

**Contract**: Add `has_many :game_sessions`.

#### 8. Factories

**File**: `spec/factories/game_sessions.rb`

**Intent**: FactoryBot definition for game sessions.

**Contract**: `game_session` factory with `creator` (user association), `game` (game association), `played_at` (defaults to `Time.current`).

**File**: `spec/factories/game_session_participants.rb`

**Intent**: FactoryBot definition for participants with traits for registered/guest and status variations.

**Contract**: `game_session_participant` factory with `game_session`, `user`, `score` (sequence). Traits: `:guest` (nulls user, sets guest_name), `:confirmed` (status confirmed), `:rejected` (status rejected).

**File**: `spec/factories/notifications.rb`

**Intent**: FactoryBot definition for notifications.

**Contract**: `notification` factory with `recipient` (user association), `notifiable` (defaults to a game_session_participant association).

#### 9. Model specs

**File**: `spec/models/game_session_spec.rb`

**Intent**: Validate associations, validations, and scopes on GameSession.

**Contract**: Cover `belongs_to` associations, presence validations, `created_by` scope, `visible_to` scope (creator sees own sessions, confirmed participant sees sessions, rejected/pending participant does not).

**File**: `spec/models/game_session_participant_spec.rb`

**Intent**: Validate the participant model's enum, validations, CHECK-like model validation, and helper methods.

**Contract**: Cover status enum, score validation, player identity validation (exactly one of user_id/guest_name), uniqueness of user per session, `confirm!`/`reject!` transitions, `registered?`/`guest?`/`display_name` helpers.

**File**: `spec/models/notification_spec.rb`

**Intent**: Validate notification associations, scopes, and read tracking.

**Contract**: Cover `belongs_to` associations, `unread` scope, `for_user` scope, `mark_as_read!` behavior.

### Success Criteria:

#### Automated Verification:

- Migrations apply cleanly: `bin/rails db:migrate`
- Model specs pass: `bin/rspec spec/models/game_session_spec.rb spec/models/game_session_participant_spec.rb spec/models/notification_spec.rb`
- Existing specs still pass: `bin/rspec`
- Linting passes: `bin/rubocop`

#### Manual Verification:

- None for Phase 1 — no user-facing UI yet. All verification is automated.

**Implementation Note**: After completing this phase and all automated verification passes, proceed to Phase 2.

---

## Phase 2: Business Logic Services

### Overview

Build the service layer that orchestrates session creation, editing, and confirm/reject flows. This phase delivers the core business logic with comprehensive unit and integration specs — all verified automatically, no manual browser testing.

### Changes Required:

#### 1. GameSessions::Create service

**File**: `app/services/game_sessions/create.rb`

**Intent**: Orchestrate the creation of a game session with all participants and notifications in a single transaction. Enforces the business rule that tagged registered players must be accepted friends of the logger.

**Contract**: `GameSessions::Create.call(creator:, game_id:, creator_score:, players:)`. The `players` parameter is an array of hashes, each describing a player (type, user_id or guest_name, score). Returns `GameSessions::CreateResult = Data.define(:status, :game_session)` with statuses: `:created`, `:game_not_found`, `:not_friends` (with details), `:invalid`.

Within a transaction:
- Filters out the creator's `user_id` from the `players` array (defensive guard against malformed params)
- Finds the game (returns `:game_not_found` if missing)
- Validates each registered player is an accepted friend of the creator
- Creates `GameSession` with `played_at: Time.current`
- Creates the logger's `GameSessionParticipant` (status: confirmed)
- Creates other participants: registered → pending + Notification; guest → confirmed, no notification
- Returns the result

#### 2. GameSessions::Update service

**File**: `app/services/game_sessions/update.rb`

**Intent**: Handle session editing with diff-based selective re-notification. Only participants whose data actually changed get reset to pending.

**Contract**: `GameSessions::Update.call(game_session:, game_id:, creator_score:, players:)`. Returns `GameSessions::UpdateResult = Data.define(:status, :game_session)` with statuses: `:updated`, `:game_not_found`, `:not_friends`, `:invalid`.

Within a transaction:
- Filters out the creator's `user_id` from the `players` array (defensive guard against malformed params)
- Detects game change — if game_id differs, resets all non-logger registered participants to pending + re-notifies
- Updates logger's score
- Diffs other participants (by id for existing, new entries for additions):
  - Existing participant removed → destroy (cascades notifications)
  - Existing registered participant with score change → update score, reset to pending, clean up old notifications, create new notification
  - New registered participant → create (pending) + notification
  - New guest → create (confirmed)
  - Guest score change → update score (no notification)
- Returns the result

#### 3. Service specs (unit)

**File**: `spec/services/unit/game_sessions/create_spec.rb`

**Intent**: Test all branches of the Create service in isolation.

**Contract**: Cover `:created` happy path (registered + guest players), `:game_not_found`, `:not_friends` (non-friend tagged), `:invalid` (bad data). Assert DB side effects: GameSession count, GameSessionParticipant count and statuses, Notification count and recipients. Assert logger is always confirmed. Assert guests are always confirmed with no notifications.

**File**: `spec/services/unit/game_sessions/update_spec.rb`

**Intent**: Test all branches and diff logic of the Update service.

**Contract**: Cover `:updated` happy path, score change re-notification, game change resets all registered, participant addition/removal, guest changes without notification, logger score change without re-notification. Assert notification cleanup on re-notification. Assert participant status transitions.

#### 4. Service specs (integration)

**File**: `spec/services/integration/game_sessions_spec.rb`

**Intent**: End-to-end flows spanning Create → Confirm/Reject → Update with real DB.

**Contract**: Cover full lifecycle: create session → friend confirms → logger edits score → friend gets re-notified → friend re-confirms. Assert privacy: rejected participant's `visible_to` excludes the session. Assert the logger always sees their sessions. Assert solo session (logger only, no other players).

### Success Criteria:

#### Automated Verification:

- Service unit specs pass: `bin/rspec spec/services/unit/game_sessions/`
- Service integration specs pass: `bin/rspec spec/services/integration/game_sessions_spec.rb`
- All existing specs still pass: `bin/rspec`
- Linting passes: `bin/rubocop`

#### Manual Verification:

- None for Phase 2 — no user-facing UI yet. All verification is automated.

**Implementation Note**: After completing this phase and all automated verification passes, proceed to Phase 3.

---

## Phase 3: Controllers, Routes, Views, Stimulus

### Overview

Wire up the full user-facing feature: controllers for game session CRUD and notification inbox, routes, ERB views with daisyUI styling, the first custom Stimulus controller for dynamic player rows, and nav updates with notification badge. This phase includes both automated request specs and manual browser testing.

### Changes Required:

#### 1. Routes

**File**: `config/routes.rb`

**Intent**: Add game session CRUD routes and notification inbox with confirm/reject member actions.

**Contract**: `resources :game_sessions, only: [:index, :new, :create, :show, :edit, :update]`. `resources :notifications, only: [:index]` with member routes `patch :confirm` and `patch :reject`. Place after existing friendship routes.

#### 2. GameSessionsController

**File**: `app/controllers/game_sessions_controller.rb`

**Intent**: CRUD controller for game sessions. Create and update delegate to services. Edit/update scoped to creator only (404 for non-creators).

**Contract**: Actions: `index` (sessions visible to current_user, newest first, eager-load game + participants), `new` (form with `@games` and `@friends` for dropdowns), `create` (delegates to `GameSessions::Create`, redirects on success, re-renders on failure), `show` (visible session with participants), `edit` (creator-only, loads same data as `new`), `update` (delegates to `GameSessions::Update`, creator-only). Strong params via private method. Flash messages for success/error. Authorization: index/show use `visible_to` scoping; edit/update use `created_by` scoping — both return 404 on IDOR.

#### 3. NotificationsController

**File**: `app/controllers/notifications_controller.rb`

**Intent**: Notification inbox with confirm/reject actions. All actions scoped to current_user's notifications.

**Contract**: Actions: `index` (unread notifications for current_user, eager-load notifiable → game_session → game), `confirm` (find notification scoped to current_user, confirm the notifiable participant, mark notification as read, redirect with flash), `reject` (same flow but reject). Returns 404 if notification belongs to another user.

#### 4. ApplicationController update

**File**: `app/controllers/application_controller.rb`

**Intent**: Add unread notification count to the nav badge data, alongside the existing friend request count.

**Contract**: New `before_action :set_unread_notification_count` (private method). Sets `@unread_notification_count` from `Notification.unread.for_user(current_user).count` when authenticated. Follows the same pattern as `set_incoming_friend_request_count`.

#### 5. Session form with Stimulus nested-form controller

**File**: `app/views/game_sessions/_form.html.erb`

**Intent**: Shared form partial for new/edit session. Game dropdown, logger score field, dynamic player rows managed by Stimulus.

**Contract**: `form_with` targeting the game session. Game dropdown populated from `@games`. "Your score" integer field for the logger. Player rows container managed by `data-controller="nested-form"`. Each player row uses a `<template>` element stamped by the Stimulus controller. Row contains: Friend/Guest toggle (radio), friend dropdown (from `@friends`, hidden when Guest selected) or guest name field (hidden when Friend selected), score field, remove button. "Add player" button triggers Stimulus action.

**File**: `app/views/game_sessions/_player_fields.html.erb`

**Intent**: Single player row partial, used both as the `<template>` source and for rendering existing participants on edit.

**Contract**: Contains the toggle, friend dropdown/guest name field (conditionally shown), score field, and remove button. Uses a placeholder index (`NEW_RECORD`) in the template that the Stimulus controller replaces with a unique timestamp.

**File**: `app/javascript/controllers/nested_form_controller.js`

**Intent**: First custom Stimulus controller. Manages add/remove of player rows on the session form.

**Contract**: Targets: `template` (the hidden template element), `container` (where rows are appended). Actions: `add` (clone template, replace placeholder index, append to container), `remove` (remove the closest player row element). Keeps field name indices unique via `Date.now()`.

#### 6. Session views

**File**: `app/views/game_sessions/new.html.erb`

**Intent**: New session page rendering the form partial.

**Contract**: `content_for :title, 'Log a Session'`. Renders `_form` partial. Centered layout (`mx-auto max-w-2xl`).

**File**: `app/views/game_sessions/edit.html.erb`

**Intent**: Edit session page rendering the form partial with existing data.

**Contract**: Same layout as new. Pre-populates form with existing session data and participant rows.

**File**: `app/views/game_sessions/index.html.erb`

**Intent**: Session history list — the logger's view of all their sessions.

**Contract**: `content_for :title, 'My Sessions'`. "Log a Session" link/button at top. Chronological list (newest first) of session cards, each showing: game name, played_at date, player list with scores and status badges (confirmed/pending/rejected for registered; no badge for guests), logger's own score highlighted. Empty state when no sessions.

**File**: `app/views/game_sessions/show.html.erb`

**Intent**: Session detail page showing full session information.

**Contract**: Game name, played_at, all participants with scores and statuses. Edit link visible only to the creator. Back link to session list.

#### 7. Notifications inbox view

**File**: `app/views/notifications/index.html.erb`

**Intent**: Dedicated inbox page listing unread notifications with inline confirm/reject actions.

**Contract**: `content_for :title, 'Notifications'`. List of notification cards, each showing: who logged the session (creator email), game name, the recipient's score, played_at date. Each card has Confirm and Reject buttons (`button_to` with `method: :patch`). Empty state when no unread notifications. Follows daisyUI card/button patterns from friendships index.

#### 8. Layout nav updates

**File**: `app/views/layouts/application.html.erb`

**Intent**: Add "Sessions" and "Notifications" links to the authenticated nav, with a badge on Notifications.

**Contract**: Add "Sessions" link (`game_sessions_path`) and "Notifications" link (`notifications_path`) with `indicator` + conditional badge showing `@unread_notification_count` (same pattern as friends badge). Place between Friends link and email display.

#### 9. Request specs

**File**: `spec/requests/game_sessions_spec.rb`

**Intent**: HTTP-level testing of all game session endpoints.

**Contract**: Cover: `GET /game_sessions` (lists visible sessions only), `GET /game_sessions/new` (renders form), `POST /game_sessions` (creates via service, redirects, flash), `GET /game_sessions/:id` (shows visible session, 404 for non-visible), `GET /game_sessions/:id/edit` (creator only, 404 for non-creator), `PATCH /game_sessions/:id` (creator only, delegates to update service). Auth guard: redirects unauthenticated to sign-in. IDOR: 404 when accessing another user's session. Nav badge: shows notification count.

**File**: `spec/requests/notifications_spec.rb`

**Intent**: HTTP-level testing of notification inbox and confirm/reject actions.

**Contract**: Cover: `GET /notifications` (lists unread for current user), `PATCH /notifications/:id/confirm` (confirms participant, marks read, redirects with flash), `PATCH /notifications/:id/reject` (rejects participant, marks read, redirects). IDOR: 404 when acting on another user's notification. Auth guard.

### Success Criteria:

#### Automated Verification:

- Request specs pass: `bin/rspec spec/requests/game_sessions_spec.rb spec/requests/notifications_spec.rb`
- All specs pass: `bin/rspec`
- Linting passes: `bin/rubocop`
- CI passes: `bin/ci`

#### Manual Verification:

- Log a new session with 1 friend + 1 guest: game selected from dropdown, scores entered, friend/guest toggle works, "Add player" and "Remove" buttons work correctly
- After submit, session appears in logger's session history at `/game_sessions`
- Sign in as the tagged friend: notification badge appears in nav; `/notifications` shows the session with Confirm/Reject buttons
- Confirm the session: notification disappears from inbox, session appears in friend's history at `/game_sessions`
- Test reject flow: rejected session does not appear in friend's history
- Edit a session (change a friend's score): friend gets re-notified (appears in their inbox again as pending)
- Edit a session (change game): all non-logger registered participants reset to pending and re-notified
- Solo session: log a session with no other players (logger only); session appears in history
- IDOR: attempt to edit another user's session → 404
- Nav shows correct badge counts for both notifications and friend requests

**Implementation Note**: After completing this phase and all verification passes (automated and manual), the feature is complete. Run `bin/ci` for full CI validation.

---

## Testing Strategy

### Model Specs:

- `GameSession`: associations, validations, `visible_to` scope (creator sees own, confirmed participant sees, rejected/pending does not)
- `GameSessionParticipant`: enum transitions, identity validation (exactly-one-of constraint), uniqueness per session, `confirm!`/`reject!`, helper methods
- `Notification`: scopes, `mark_as_read!`, polymorphic association

### Service Unit Specs:

- `GameSessions::Create`: all result statuses (`:created`, `:game_not_found`, `:not_friends`, `:invalid`), participant counts and statuses, notification creation, solo session
- `GameSessions::Update`: score change re-notification, game change bulk reset, add/remove participants, guest-only changes (no notification), logger score change (no re-notification)

### Service Integration Specs:

- Full lifecycle: create → confirm → edit → re-confirm
- Privacy boundary: rejected participant excluded from `visible_to`
- Friendship validation: tagging a non-friend returns `:not_friends`

### Request Specs:

- CRUD happy paths with redirects and flash
- Auth guards (redirect to sign-in)
- IDOR protection (404 for wrong user)
- Notification confirm/reject with participant status assertions
- Nav badge counts

### Manual Testing Steps:

1. Create session with mixed players (friend + guest), verify history
2. Confirm as friend, verify it appears in friend's history
3. Reject as friend, verify it does NOT appear in friend's history
4. Edit session (score change), verify only affected friend re-notified
5. Edit session (game change), verify all registered participants re-notified
6. Solo session (logger only), verify it works
7. Verify notification badge in nav updates correctly

## Performance Considerations

- `visible_to` scope uses a subquery on `game_session_participants` — index on `[game_session_id, user_id]` covers this
- Notification count query runs on every authenticated request (via `before_action`) — index on `[recipient_id, read_at]` keeps this fast
- Session index eager-loads game + participants to avoid N+1 — use `.includes(:game, game_session_participants: :user)`
- For MVP data volumes (few users, <100 sessions), no pagination needed; add in S-04 if needed

## Migration Notes

- No existing data to migrate — all three tables are new
- `played_at` defaults to `Time.current` at creation; no date picker in UI, but the column exists for future use and S-04 stat filtering
- The `notifications` table is designed to be generic (polymorphic) but initially only serves `GameSessionParticipant` notifications

## References

- PRD: `context/foundation/prd.md` — US-01, FR-003, FR-004, FR-005, FR-006, FR-009
- Roadmap: `context/foundation/roadmap.md` — S-03 (lines 133-143)
- S-02 research (notification deferral, participant shape): `context/archive/2026-07-14-mutual-friend-circle/research.md:126-146`
- Service convention: `app/AGENTS.md:34-42`
- Spec convention: `spec/AGENTS.md`
- Friendship controller (pattern to follow): `app/controllers/friendships_controller.rb`
- Friendship model (enum + scopes pattern): `app/models/friendship.rb`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Data Model Foundation

#### Automated

- [x] 1.1 Migrations apply cleanly: `bin/rails db:migrate`
- [x] 1.2 Model specs pass: `bin/rspec spec/models/game_session_spec.rb spec/models/game_session_participant_spec.rb spec/models/notification_spec.rb`
- [x] 1.3 Existing specs still pass: `bin/rspec`
- [x] 1.4 Linting passes: `bin/rubocop`

### Phase 2: Business Logic Services

#### Automated

- [ ] 2.1 Service unit specs pass: `bin/rspec spec/services/unit/game_sessions/`
- [ ] 2.2 Service integration specs pass: `bin/rspec spec/services/integration/game_sessions_spec.rb`
- [ ] 2.3 All existing specs still pass: `bin/rspec`
- [ ] 2.4 Linting passes: `bin/rubocop`

### Phase 3: Controllers, Routes, Views, Stimulus

#### Automated

- [ ] 3.1 Request specs pass: `bin/rspec spec/requests/game_sessions_spec.rb spec/requests/notifications_spec.rb`
- [ ] 3.2 All specs pass: `bin/rspec`
- [ ] 3.3 Linting passes: `bin/rubocop`
- [ ] 3.4 CI passes: `bin/ci`

#### Manual

- [ ] 3.5 Log a session with 1 friend + 1 guest; verify history
- [ ] 3.6 Confirm as friend; verify session in friend's history
- [ ] 3.7 Reject as friend; verify session excluded from friend's history
- [ ] 3.8 Edit session (score change); verify selective re-notification
- [ ] 3.9 Edit session (game change); verify bulk re-notification
- [ ] 3.10 Solo session (logger only); verify it works
- [ ] 3.11 Notification badge in nav shows correct count
- [ ] 3.12 IDOR: attempt to edit another user's session → 404
