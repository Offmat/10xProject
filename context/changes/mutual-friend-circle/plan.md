# Mutual Friend Circle (S-02) Implementation Plan

## Overview

Deliver roadmap slice **S-02**: a registered user can send a friend request to another registered user by email, the addressee can accept or decline, and the friendship is active only after mutual acceptance. The user also sees their active friends, incoming requests, and outgoing pending requests on one page, with a nav badge counting incoming requests. This unblocks the north star **S-03** (`roadmap.md:133`), which requires at least one accepted friend to tag a registered co-player.

## Current State Analysis

Everything in this slice is greenfield (confirmed in `research.md:37-45`). The schema has only `users`, auth `sessions`, and `games` (`db/schema.rb`). Routes are auth + catalog only (`config/routes.rb:1-16`). No `Friendship`, no friends UI, no `Notification` model exists.

Established conventions this plan follows (from `research.md:47-53` and direct reads):

- **Migrations**: domain columns first, `t.timestamps`, indexes after the block — `db/migrate/20260607120000_create_games.rb`.
- **Models**: inline `validates` / `enum` / associations, no fat callbacks — `app/models/user.rb:1-10`, `app/models/game.rb`.
- **Controllers**: `include Authentication` (default `require_authentication`), thin actions, strong params in a private method, flash-based redirects — `app/controllers/users_controller.rb:1-30`, `app/controllers/sessions_controller.rb`.
- **Domain code must not read `Current`/cookies**: pass `current_user` in explicitly (`app/AGENTS.md:27`).
- **Services**: namespaced `app/services/<domain>/`, single public `.call`, private `attr_reader` for instance vars; no `ApplicationService` base until 5+ share boilerplate (`app/AGENTS.md:34-42`). Orchestrator naming after the action (`CreateSession`, `ImportService`).
- **Views**: daisyUI ERB, `content_for :title`, `form_with`, flash via `shared/_flash` — `app/views/users/new.html.erb`, `app/views/layouts/application.html.erb:26-41`.
- **Specs**: request specs are the primary HTTP surface; model specs for scopes/validations; FactoryBot; auth helpers `sign_in_as` / `register_user` (`spec/AGENTS.md`, `spec/support/authentication_helpers.rb`).

## Desired End State

Two registered users can establish a mutual friendship end-to-end through the UI:

- A signs in, opens **Friends**, enters B's exact email, and sends a request.
- B signs in, sees a **badge** on the Friends nav link and an **Incoming requests** entry, and clicks **Accept** (or **Decline**).
- After accept, B appears in A's **Active friends** and A appears in B's — the relationship is symmetric.
- A can **Cancel** a still-pending outgoing request. If B declines, A can re-send (the same row flips back to pending). If B had already requested A when A sends, the request auto-accepts.

Verification: request specs cover send/accept/decline/cancel, reciprocal auto-accept, decline-then-re-request, and IDOR negatives (a non-participant cannot accept/decline someone else's request). Manual: run the two-account flow in the browser.

### Key Discoveries:

- **One row per relationship** with `enum status: { pending, accepted, declined }`, `requester_id`/`addressee_id` → `users`, unique index on the ordered pair (`research.md:106-124`). "Active friends" = accepted rows where I am either side.
- **No `Notification` table** — a pending incoming request *is* the notification; the inbox and the nav badge are queries: `Friendship.pending.where(addressee: current_user)` (`research.md:126-146`).
- The unique index is on the **ordered** pair `[requester_id, addressee_id]`, so a reciprocal B→A does **not** collide with A→B at the DB level — reciprocal detection must query both directions in the service (`research.md:117-123`).
- Anti-enumeration precedent exists in auth (`users_controller.rb:18-21`, `authentication_spec.rb:131-147`); this slice deliberately diverges for the "add friend by email" error copy (see Open Risks).

## What We're NOT Doing

- **No `Notification` / polymorphic inbox** — deferred to S-03 when a second notification type exists (`research.md:138-146`).
- **No unfriend / remove-friend** action — deferred; traced to `roadmap.md` Parked in Phase 3.
- **No blocking / mute** of users.
- **No guest/participant (`session_players`) schema** — that is S-03 territory (`research.md:68-100`).
- **No email or push notifications** — in-app only, per PRD Non-Goals (`prd.md:144`).
- **No username/handle** system — discovery is exact-email only.
- **No re-request cooldown or rate limit** on friend requests in this slice (revisit if abuse appears).

## Implementation Approach

Three phases, each independently verifiable and building on the prior:

1. **Data model** — migration + `Friendship` model + `User` associations + scopes, proven by a model spec.
2. **Request flow** — routes, a `Friendships::CreateRequest` service that owns the branching logic (email lookup, guards, reciprocal auto-accept, declined-row reuse), and a thin `FriendshipsController` with authorization; proven by request specs including IDOR negatives.
3. **UI + docs** — the `/friends` page, nav link + badge, distinct flash messages, and the roadmap Parked trace.

The only non-trivial business logic (the create-request branching) is isolated in one service; the simple status transitions (accept/decline/cancel) stay as thin controller actions calling model methods, honoring the repo's "defer abstraction" culture.

## Critical Implementation Details

- **Reciprocal auto-accept vs the unique index.** The unique index is on the ordered pair, so A→B and B→A are two distinct rows at the DB level. The `CreateRequest` service must therefore look up an existing relationship in *both* directions before creating: if a pending B→A exists, flip it to `accepted` instead of inserting A→B; if a declined A→B exists, reuse (flip to `pending`) rather than insert (the insert would raise on the unique index).
- **Concurrency of the read-then-write.** The reverse-direction lookup and the subsequent create/flip must run inside a single `transaction`; without it, near-simultaneous A→B and B→A requests can both miss each other's pending row and insert two pending rows (the ordered-pair index does not prevent this), leaving a stale pending outgoing request after one side accepts. Wrap branches 3–7 in a `Friendship.transaction do … end` and, immediately after any insert, re-check for a pending reverse row created concurrently; if one is found, reconcile to a single `accepted` row (accept one, discard/skip the redundant insert) so the outcome matches the reciprocal auto-accept path. Extremely unlikely at friend-circle scale, but this keeps the "reciprocal auto-accept works" end-state guarantee honest.
- **Symmetric "friends" query.** "My friends" spans rows where I am requester OR addressee and status is accepted. Implement as a scope that takes the user id and filters both columns, then resolves the *other* side to the friend `User`.

## Phase 1: Friendship data model & associations

### Overview

Create the `friendships` table, the `Friendship` model with status enum, associations, validations, and scopes, and wire `User` associations plus a `friends` helper. Prove it with a model spec.

### Changes Required:

#### 1. Migration

**File**: `db/migrate/<timestamp>_create_friendships.rb`

**Intent**: Persist one row per directed relationship with a status, guarding against duplicate ordered pairs at the DB level. Follow the games migration column order/style.

**Contract**: `create_table :friendships` with `t.references :requester` and `t.references :addressee`, both `null: false, foreign_key: { to_table: :users }`; `t.integer :status, null: false, default: 0`; `t.timestamps`. After the block: `add_index :friendships, [:requester_id, :addressee_id], unique: true`. (The `references` calls generate their own single-column indexes for the reverse-lookup scopes.)

#### 2. Friendship model

**File**: `app/models/friendship.rb`

**Intent**: Model the relationship with a status enum, both associations pointing at `User`, a self-friend guard, and the scopes the controller/badge/UI need. Keep status transitions as small instance methods so the controller stays thin.

**Contract**:
- `belongs_to :requester, class_name: 'User'` and `belongs_to :addressee, class_name: 'User'`.
- `enum :status, { pending: 0, accepted: 1, declined: 2 }`.
- `validate` rejecting `requester_id == addressee_id` (no self-friend).
- Scopes: `pending`/`accepted`/`declined` come from the enum; add `incoming_for(user)` (`pending` where `addressee: user`), `outgoing_for(user)` (`pending` where `requester: user`), and `involving(user)` (rows where requester OR addressee is user). Add an `accepted_involving(user)` (accepted + involving) for the friends list.
- Instance transitions: `accept!` (set `accepted`), `decline!` (set `declined`). These are thin wrappers over `update!(status: …)`; reciprocal/reuse logic lives in the service, not here.

#### 3. User associations + friends helper

**File**: `app/models/user.rb`

**Intent**: Let a user reach their friendship rows from both sides and resolve the set of accepted friend `User` records.

**Contract**: `has_many :sent_friendships` (`class_name: 'Friendship', foreign_key: :requester_id, dependent: :destroy`) and `has_many :received_friendships` (`class_name: 'Friendship', foreign_key: :addressee_id, dependent: :destroy`). A `friends` method returning the accepted counterpart `User`s as an `ActiveRecord::Relation` (not an Array), in a single query with no N+1: derive the counterpart id for each row in `Friendship.accepted_involving(self)` (the side that isn't `self.id`) and return `User.where(id: counterpart_ids)`. Returning a relation lets the view iterate and lets callers chain `order`/`count` later.

### Success Criteria:

#### Automated Verification:

- Migration applies cleanly: `bin/rails db:migrate` (and `db:test:prepare`)
- Model spec passes: `bin/rspec spec/models/friendship_spec.rb`
- Linting passes: `bin/rubocop`

#### Manual Verification:

- In `bin/rails console`: create two users, create a pending `Friendship`, `accept!` it, and confirm each user's `friends` returns the other.

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 2.

---

## Phase 2: Friend request flow (routes, service, controller)

### Overview

Expose the request lifecycle over HTTP: send by email (with all branching in a service), accept, decline, cancel — with authorization so only the right party can act. Prove it with request specs including IDOR negatives.

### Changes Required:

#### 1. Routes

**File**: `config/routes.rb`

**Intent**: Add the friendships surface: an index, a create, member accept/decline, and cancel.

**Contract**: `resources :friendships, only: %i[index create destroy]` with `member` block adding `patch :accept` and `patch :decline`. (`destroy` = requester cancels a pending outgoing request.)

#### 2. Create-request service

**File**: `app/services/friendships/create_request.rb`

**Intent**: Own every branch of "send a request by email" so the controller stays thin. Look up the addressee by exact (normalized) email, apply guards, and return a result object the controller maps to flash copy.

**Contract**: `Friendships::CreateRequest.call(requester:, email:)` returning a small result (e.g. a `Struct`/`Data` with `status` symbol + optional `friendship`). Run branches 3–7 (all lookups + the create/flip) inside a single `Friendship.transaction`, and after an insert re-check for a concurrently-created pending reverse row, reconciling to one `accepted` row if found (see Critical Implementation Details → Concurrency). Branch order:
1. Normalize email the same way `User` does (`strip.downcase`); find addressee. Not found → `:not_found`.
2. Addressee is the requester → `:self_request`.
3. An accepted row involving both (either direction) exists → `:already_friends`.
4. A pending row this direction (requester→addressee) exists → `:already_requested`.
5. A pending row the reverse direction (addressee→requester) exists → flip it to `accepted`, return `:auto_accepted`.
6. A declined row this direction exists → flip it back to `pending`, return `:requested` (reuse — do not insert, the unique index would raise).
7. Otherwise create a new pending row → `:requested`.

Pass `current_user` in explicitly; do not read `Current` (`app/AGENTS.md:27`).

#### 3. FriendshipsController

**File**: `app/controllers/friendships_controller.rb`

**Intent**: Thin actions over the service and model transitions, with authorization scoping so users can only act on their own rows.

**Contract**:
- `include Authentication` by default (no `allow_unauthenticated_access`).
- `index`: load `@friends` (`current_user.friends`), `@incoming` (`Friendship.incoming_for(current_user)`), `@outgoing` (`Friendship.outgoing_for(current_user)`).
- `create`: delegate to `Friendships::CreateRequest`; translate the result status into a distinct flash message (see Phase 3 copy) and redirect to `friendships_path`.
- `accept` / `decline`: load the row via `Friendship.incoming_for(current_user).find(params[:id])` so a non-addressee gets `RecordNotFound` (404) — this is the IDOR guard; then `accept!` / `decline!`.
- `destroy` (cancel): load via `Friendship.outgoing_for(current_user).find(params[:id])` (only the requester, only while pending) then `destroy!`.
- Let `ActiveRecord::RecordNotFound` produce the standard 404 (do not rescue into the happy path).

### Success Criteria:

#### Automated Verification:

- Request spec passes: `bin/rspec spec/requests/friendships_spec.rb`
- Service unit spec passes: `bin/rspec spec/services/unit/friendships/create_request_spec.rb`
- Linting passes: `bin/rubocop`
- Security scan clean: `bin/brakeman`

#### Manual Verification:

- With two browser sessions (two accounts), send → accept works; reciprocal send auto-accepts; decline then re-send works; cancel removes a pending outgoing request.
- Attempting to accept another user's request (wrong `id`) returns 404, not success.

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 3.

---

## Phase 3: Friends UI, nav badge & documentation

### Overview

Build the single `/friends` page (three sections + add-by-email form), the nav "Friends" link with an incoming-request count badge, distinct flash copy, and record the deferred unfriend decision in the roadmap.

### Changes Required:

#### 1. Friends page

**File**: `app/views/friendships/index.html.erb`

**Intent**: One page showing Active friends, Incoming requests (Accept/Decline), Outgoing pending (Cancel), and an "Add a friend by email" form. Mirror the daisyUI styling of the auth views.

**Contract**: `content_for :title, 'Friends'`. An add form (`form_with url: friendships_path`, email field) styled like `users/new.html.erb`. Three sections rendering `@friends`, `@incoming` (each with `button_to` Accept → `accept_friendship_path`, method `:patch`; Decline → `decline_friendship_path`), and `@outgoing` (each with `button_to` Cancel → `friendship_path`, method `:delete`). Show the counterpart user's email as the label. Empty-state text per section.

#### 2. Distinct flash copy for create results

**File**: `app/controllers/friendships_controller.rb` (create action) — copy defined here, rendered by `shared/_flash`.

**Intent**: Map each service result to a clear, distinct message (per product decision, including "no such user").

**Contract**: `:requested` → notice "Friend request sent."; `:auto_accepted` → notice "You're now friends — they had already sent you a request."; `:already_friends` → alert "You're already friends."; `:already_requested` → alert "You already have a pending request to that person."; `:self_request` → alert "You can't send a friend request to yourself."; `:not_found` → alert "No account found with that email." (deliberate divergence from anti-enumeration — see Open Risks).

#### 3. Nav link + incoming-request badge

**File**: `app/views/layouts/application.html.erb`

**Intent**: Add a "Friends" nav link visible when authenticated, with a daisyUI badge showing the count of incoming pending requests (a query, no table).

**Contract**: In the authenticated branch of `navbar-end` (`:31-37`), add `link_to` to `friendships_path` with an `indicator`/`badge` showing `Friendship.incoming_for(current_user).count` when `> 0`. Keep it a simple count query; acceptable cost at MVP scale.

#### 4. Roadmap trace for deferred unfriend

**File**: `context/foundation/roadmap.md`

**Intent**: Record that unfriend/remove-friend was consciously deferred out of S-02 so it isn't lost.

**Contract**: Add a bullet under `## Parked` (`roadmap.md:175`): "**Unfriend / remove friend** — Why parked: deferred from S-02 (mutual-friend-circle) to keep the slice focused on send/accept/decline/cancel; PRD does not require it. Revisit alongside session-tagging implications in or after S-03."

### Success Criteria:

#### Automated Verification:

- Request spec asserts the three sections render and the badge count reflects incoming pending requests: `bin/rspec spec/requests/friendships_spec.rb`
- Linting passes: `bin/rubocop`

#### Manual Verification:

- `/friends` renders all three sections with correct data for the signed-in user; Accept/Decline/Cancel buttons work and update the page.
- Nav badge shows the incoming count and disappears at zero.
- Each add-by-email outcome (success, self, already-friends, pending, unknown email) shows its distinct flash.
- Styling is consistent with the existing auth/daisyUI views.
- Roadmap `## Parked` entry for deferred unfriend/remove-friend is added (`context/foundation/roadmap.md`).

**Implementation Note**: After automated verification passes, pause for final manual confirmation.

---

## Testing Strategy

### Unit Tests (service):

- `Friendships::CreateRequest`: each branch — `:requested` (new), `:auto_accepted` (reciprocal), reuse of a declined row (`:requested`, no new row / no unique-index error), `:already_friends`, `:already_requested`, `:self_request`, `:not_found`. Assert DB side effects (row count, status), not only the return value (`spec/AGENTS.md`).

### Model Tests:

- Enum values; self-friend validation rejects; `incoming_for` / `outgoing_for` / `accepted_involving` return the right rows; `User#friends` resolves the counterpart on both sides.

### Integration / Request Tests:

- Full send → accept path; send → decline → re-send path; cancel a pending outgoing request.
- **IDOR negatives**: a signed-in non-addressee accepting/declining another pair's request → 404; a non-requester cancelling → 404.
- Index renders the three sections for the current user only; badge count matches incoming pending.

### Manual Testing Steps:

1. Register two users in two browsers.
2. From A, add B by email → B sees badge + incoming request.
3. B accepts → both see each other in Active friends.
4. Repeat with decline, then A re-sends successfully.
5. A sends to B while B→A is pending → auto-accepted.
6. A cancels a pending outgoing request.
7. Try each error case for the add form.

## Performance Considerations

Data volume is small (`prd.md` target_scale). The nav badge is one indexed `COUNT` per authenticated render — negligible. Friend/inbox queries are indexed by the `references` columns.

## Migration Notes

Single additive migration; no existing data to backfill. `bin/rails db:migrate` then `bin/rails db:test:prepare` before running specs.

## References

- Research: `context/changes/mutual-friend-circle/research.md`
- Schema/model conventions: `app/models/user.rb:1-10`, `app/models/game.rb`, `db/migrate/20260607120000_create_games.rb`
- Controller/auth conventions: `app/controllers/users_controller.rb:1-30`, `app/controllers/concerns/authentication.rb`
- Service convention: `app/services/game_catalog/import_service.rb`, `app/AGENTS.md:34-42`
- View/nav conventions: `app/views/users/new.html.erb`, `app/views/layouts/application.html.erb:26-41`
- Spec conventions: `spec/requests/authentication_spec.rb`, `spec/support/authentication_helpers.rb`, `spec/AGENTS.md`
- Roadmap slice: `context/foundation/roadmap.md:121-131`

## Open Risks & Assumptions

- **Enumeration divergence (accepted).** The add-by-email form returns a distinct "No account found with that email" message, which lets a user probe whether an email is registered — this diverges from the anti-enumeration stance in auth (`users_controller.rb:18-21`). This was an explicit product decision; revisit if abuse or privacy concerns arise (swap to a neutral "if that account exists, a request was sent").
- **No re-request rate limit.** Decline-then-re-request has no cooldown; a determined user could re-pester. Acceptable for a small friend-circle MVP; add `rate_limit` later if needed.
- **Assumption:** email is the only stable identifier (no usernames), so exact-email lookup is the discovery mechanism.
- **Reciprocal concurrency residual (accepted for MVP).** Transaction + post-insert reverse re-check are in place, but under Postgres READ COMMITTED two overlapping A→B / B→A transactions can still both commit `pending` if neither sees the other's uncommitted insert — `reconcile_concurrent_reverse!` then never fires. Extremely unlikely at friend-circle scale; `pg_advisory_xact_lock` on the unordered pair was deferred. Revisit before hardening if product needs a hard auto-accept guarantee under concurrency.
- **Naming drift (accepted).** Scopes shipped as `incoming_to` / `outgoing_from` (not `incoming_for` / `outgoing_for`); service kwarg is `addressee_email:` (not `email:`). Intentional clarity renames — behavior matches the plan.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Friendship data model & associations

#### Automated

- [x] 1.1 Migration applies cleanly: `bin/rails db:migrate` + `db:test:prepare` — ac1f38c
- [x] 1.2 Model spec passes: `bin/rspec spec/models/friendship_spec.rb` — ac1f38c
- [x] 1.3 Linting passes: `bin/rubocop` — ac1f38c

#### Manual

- [x] 1.4 Console: create two users, create pending friendship, `accept!`, confirm `friends` resolves both sides — ac1f38c

### Phase 2: Friend request flow (routes, service, controller)

#### Automated

- [x] 2.1 Request spec passes: `bin/rspec spec/requests/friendships_spec.rb` — 5aeff70
- [x] 2.2 Service unit spec passes: `bin/rspec spec/services/unit/friendships/create_request_spec.rb` — 5aeff70
- [x] 2.3 Linting passes: `bin/rubocop` — 5aeff70
- [x] 2.4 Security scan clean: `bin/brakeman` — 5aeff70

#### Manual

- [x] 2.5 Two-account browser flow: send→accept, reciprocal auto-accept, decline→re-send, cancel — 5aeff70
- [x] 2.6 Accepting/declining another pair's request returns 404 (IDOR) — 5aeff70

### Phase 3: Friends UI, nav badge & documentation

#### Automated

- [x] 3.1 Request spec asserts three sections render and badge count is correct: `bin/rspec spec/requests/friendships_spec.rb` — 5aeff70
- [x] 3.2 Linting passes: `bin/rubocop` — 5aeff70

#### Manual

- [x] 3.3 `/friends` renders all three sections with correct per-user data; Accept/Decline/Cancel work — 5aeff70
- [x] 3.4 Nav badge shows incoming count and disappears at zero — 5aeff70
- [x] 3.5 Each add-by-email outcome shows its distinct flash — 5aeff70
- [x] 3.6 Styling consistent with existing daisyUI views — 5aeff70
- [x] 3.7 Roadmap Parked entry for unfriend added — 5aeff70
