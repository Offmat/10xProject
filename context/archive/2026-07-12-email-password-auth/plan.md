# Email/Password Auth Implementation Plan

## Overview

Ship roadmap slice **S-01**: the first user-visible auth experience on top of F-01's working scaffold. Users can create an account, log in, and log out through polished daisyUI pages, see authenticated state in the navbar and home page, and benefit from F-01 impl-review security carry-forwards (bounded sessions, sweep, anti-enumeration registration).

## Current State Analysis

F-01 (`minimal-auth-scaffold`) delivered the full auth backend: `User` with `has_secure_password`, DB-backed `Session` records, `Authentication` concern with signed `session_id` cookie, `UsersController` / `SessionsController` / `PasswordsController`, rate limiting, audit logging, and comprehensive request specs.

Gaps for S-01:

- Auth views (`sessions/new`, `users/new`, `passwords/new`, `passwords/edit`) are bare HTML with no daisyUI classes.
- Layout navbar always shows Sign in / Sign up — no sign-out, no `authenticated?` branching.
- Home page is identical for all visitors — no welcome state for logged-in users.
- Session cookie uses `cookies.signed.permanent` (~20-year expiry); no server-side TTL enforcement.
- No `Session.sweep` cleanup despite `index_sessions_on_created_at` index.
- Registration renders model validation errors verbatim (email enumeration risk).
- `ApplicationCable::Connection` looks up sessions without TTL scope (same gap as HTTP).

### Key Discoveries:

- `app/controllers/concerns/authentication.rb:50-56` — permanent cookie; replace with bounded `expires`.
- `app/views/layouts/application.html.erb:30-32` — static nav links; branch on `authenticated?`.
- `app/controllers/users_controller.rb:17-18` — failed save renders model errors; replace with generic copy.
- `context/archive/2026-06-02-minimal-auth-scaffold/plan.md` impl-review addendum — explicit S-01 carry-forward checklist.
- F-03 layout + `shared/flash` already provide daisyUI patterns; auth views never adopted them.
- No `staging` Rails env — use `ENV['FORCE_SECURE_COOKIES']` for HTTPS non-production deploys.

## Desired End State

A visitor can sign up, sign in, and sign out through styled auth pages. Logged-in users see their email (truncated on small screens) and a Sign out control in the navbar, plus a personalized welcome on the home page. Sessions expire after 30 days (cookie + server-side). Stale session rows are removable via `bin/rails sessions:sweep`. Registration failures never reveal whether an email is already registered.

### Verification

- `bin/rspec spec/requests/authentication_spec.rb spec/models/session_spec.rb` passes.
- `bin/rubocop` and `bin/ci` pass.
- Manual: sign up → welcome home → navbar shows email + sign out → sign out → generic failure on duplicate registration.

## What We're NOT Doing

- OAuth, passwordless, MFA, or admin roles.
- "Remember me" checkbox or variable session lengths.
- New `/dashboard` route or functional feature placeholders beyond welcome copy.
- ActiveJob recurring sweep (rake task + ops scheduling only).
- View specs asserting CSS class names.
- Display name field on `User` (greeting derives from email local-part only).
- Changing password-reset business logic (only restyle views).

## Implementation Approach

Three incremental phases: harden session security first (backend-only, testable in isolation), then ship visible UX (shared auth partial, four views, nav, home), then extend specs and document ops for sweep scheduling. Preserve F-01 architecture — no Devise, no new controllers, cookie/session plumbing stays in `Authentication` concern.

## Critical Implementation Details

**Action Cable parity:** When adding `Session.active` scope, update `ApplicationCable::Connection#set_current_user` to use the same active lookup as `find_session_by_cookie` — otherwise WebSocket auth would accept expired sessions that HTTP rejects.

**Generic registration errors:** On failed save, if the only errors are on `:email`, set a generic `@registration_error` and clear `@user.errors` to prevent enumeration. If errors include `:password` or `:password_confirmation`, let those through normally — they carry no enumeration risk and give actionable feedback.

## Phase 1: Session Hardening

### Overview

Replace permanent session cookies with a 30-day TTL, enforce expiry server-side, add stale-row cleanup, and support secure cookies on HTTPS staging.

### Changes Required:

#### 1. Session model — lifetime constant, active scope, sweep

**File**: `app/models/session.rb`

**Intent**: Centralize session lifetime policy and provide server-side enforcement + cleanup API.

**Contract**: Add `LIFETIME = 30.days`, scope `active` (`where('created_at > ?', LIFETIME.ago)`), and class method `sweep` deleting rows where `created_at <= LIFETIME.ago`. Return count deleted from `sweep`.

#### 2. Authentication concern — bounded cookie and active lookup

**File**: `app/controllers/concerns/authentication.rb`

**Intent**: Align cookie expiry and DB lookup with `Session::LIFETIME`; extract secure-cookie predicate for staging.

**Contract**: `find_session_by_cookie` uses `Session.active.find_by(id: …)`. Replace `cookies.signed.permanent` with `cookies.signed[:session_id]` including `expires: Session::LIFETIME.from_now`. Add private `secure_session_cookie?` returning `Rails.env.production? || ENV['FORCE_SECURE_COOKIES'] == 'true'`. Keep `httponly: true`, `same_site: :lax`.

#### 3. Action Cable connection — active session lookup

**File**: `app/channels/application_cable/connection.rb`

**Intent**: Reject expired sessions on WebSocket connect, matching HTTP behavior.

**Contract**: `Session.active.find_by(id: cookies.signed[:session_id])` in `set_current_user`.

#### 4. Sessions sweep rake task

**File**: `lib/tasks/sessions.rake`

**Intent**: Operator-invokable cleanup for stale session rows; document scheduling in plan brief.

**Contract**: Namespace `sessions`, task `sweep` calling `Session.sweep` and printing deleted count. Follow pattern from `lib/tasks/game_catalog.rake`.

### Success Criteria:

#### Automated Verification:

- `bin/rspec spec/models/session_spec.rb` — existing specs pass (no regression)
- `bin/rspec spec/requests/authentication_spec.rb` — existing specs pass (no regression)
- `bin/rubocop` passes on touched files

#### Manual Verification:

- Sign in, verify cookie has ~30-day expiry in browser devtools (not year 2044)
- `bin/rails sessions:sweep` runs without error and reports count

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 2: Auth UI & Navigation

### Overview

Restyle all auth pages with a shared daisyUI card layout, add authenticated navbar + sign-out, personalize home page, and harden registration error display.

### Changes Required:

#### 1. Shared auth card partial

**File**: `app/views/shared/_auth_card.html.erb`

**Intent**: DRY layout for centered auth forms — title, optional subtitle, yield for form body, footer links.

**Contract**: Accept locals `title:` (required), `subtitle:` (optional). Use daisyUI `card`, `card-body`, `form-control`, `label`, `input input-bordered`, `btn btn-primary`, `link link-primary`. Max-width centered container consistent with `pages/home.html.erb`.

#### 2. Restyle sign-in view

**File**: `app/views/sessions/new.html.erb`

**Intent**: Apply shared auth card; set page title via `content_for :title`.

**Contract**: Render `_auth_card` with title "Sign in". Form fields use daisyUI input classes. Footer links to forgot password and sign up. No inline flash blocks (layout `shared/flash` handles controller flash).

#### 3. Restyle sign-up view

**File**: `app/views/users/new.html.erb`

**Intent**: Match sign-in styling; show generic error alert only.

**Contract**: Render `_auth_card` with title "Sign up". Error display: daisyUI `alert alert-error` when `@registration_error` present (generic anti-enumeration case); standard model error display for password validation errors when `@user.errors` has non-email entries. Footer link to sign in.

#### 4. Restyle password reset views

**Files**: `app/views/passwords/new.html.erb`, `app/views/passwords/edit.html.erb`

**Intent**: Consistent auth page styling for forgot/reset password flows.

**Contract**: Both use `_auth_card` partial with appropriate titles. Same input/btn classes as sign-in.

#### 5. Generic registration failure in controller

**File**: `app/controllers/users_controller.rb`

**Intent**: Prevent email enumeration on failed registration while preserving actionable password feedback.

**Contract**: On failed `save`, check whether errors exist only on `:email` (e.g. uniqueness violation). If so, set `@registration_error = 'Unable to create account. Check your details and try again.'` — a generic string that hides whether the email is taken. If errors include non-email attributes (`:password`, `:password_confirmation`), allow those model errors through to the view normally (they carry no enumeration risk). Render `:new, status: :unprocessable_entity` in both cases.

#### 6. Authenticated navbar

**File**: `app/views/layouts/application.html.erb`

**Intent**: Show sign-out and user identity when logged in; hide sign-in/sign-up links.

**Contract**: Branch on `authenticated?`. When true: display `current_user.email` with Tailwind truncate (`max-w-[12rem] sm:max-w-none`) and `button_to 'Sign out', session_path, method: :delete, class: 'btn btn-ghost btn-sm'`. When false: existing Sign in / Sign up links unchanged.

#### 7. Welcome message on home page

**File**: `app/views/pages/home.html.erb`

**Intent**: Greet authenticated users by email local-part; keep existing copy for guests.

**Contract**: When `authenticated?`, show heading like "Welcome back, {local-part}" (derive via `current_user.email.split('@').first`) above or replacing the generic tagline area. Guests see current unauthenticated content unchanged.

### Success Criteria:

#### Automated Verification:

- `bin/rspec spec/requests/authentication_spec.rb` — existing specs pass (no regression)
- `bin/rubocop` passes on touched files

#### Manual Verification:

- Sign up, sign in, forgot password, and reset password pages render styled cards on mobile and desktop
- Navbar truncates long email on narrow viewport
- Duplicate registration shows generic error only
- Sign out returns to sign-in page; navbar reverts to guest links

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 3: Tests & Verification

### Overview

Fill spec gaps for S-01 decisions, add sweep task coverage, and run full CI.

### Changes Required:

#### 1. Session model specs

**File**: `spec/models/session_spec.rb`

**Intent**: Verify `active` scope boundary and `sweep` deletion behavior.

**Contract**: Examples for session inside/outside 30-day window; `sweep` removes only stale rows.

#### 2. Authentication request spec extensions

**File**: `spec/requests/authentication_spec.rb`

**Intent**: Lock in nav, home welcome, registration anti-enumeration, and expired-session rejection.

**Contract**: New examples: authenticated GET root includes welcome + sign-out control; POST users with duplicate email returns generic message without "already been taken"; session older than 30 days treated as logged out on protected request.

#### 3. Sweep rake task spec (optional lightweight)

**File**: `spec/tasks/sessions_rake_spec.rb` (or inline in model spec if task is thin)

**Intent**: Smoke-test rake task invokes `Session.sweep`.

**Contract**: Task output includes deleted count; stale factory session removed.

#### 4. Infrastructure note for ops

**File**: `context/changes/email-password-auth/plan-brief.md` (already written — verify sweep scheduling note present)

**Intent**: Document that Railway/cron should run `bin/rails sessions:sweep` periodically (e.g. daily).

**Contract**: Note in plan-brief Prerequisites/Ops section; no code change if already captured.

### Success Criteria:

#### Automated Verification:

- `bin/rspec` full suite passes
- `bin/rubocop` passes
- `bin/ci` passes (or equivalent: RuboCop, bundler-audit, Brakeman, RSpec)

#### Manual Verification:

- End-to-end smoke: register → welcome home → sign out → sign in → sign out
- Visual check: abyss theme consistent across auth pages and layout

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before marking the change implemented.

---

## Testing Strategy

### Unit Tests:

- `Session.active` scope at TTL boundary (29 days active, 31 days inactive)
- `Session.sweep` deletes only expired rows, returns count

### Integration / Request Tests:

- Full register → sign-in → sign-out flow (existing, keep green)
- Nav HTML includes sign-out when authenticated, excludes sign-up link
- Home page welcome for authenticated user
- Duplicate registration generic error
- Expired session cookie rejected (create session with backdated `created_at`)

### Manual Testing Steps:

1. Register new account — styled form, redirect to welcome home, navbar shows email + sign out
2. Sign out — navbar reverts, home shows guest copy
3. Sign in with wrong password — flash error, styled form
4. Register with existing email — generic error, no "already been taken"
5. Forgot password flow — styled pages, email sends (check logs in dev)
6. `bin/rails sessions:sweep` after creating old session row in console

## Performance Considerations

Negligible — one indexed `created_at` filter on session lookup. Sweep is batch delete on stale rows; schedule daily to keep table small.

## Migration Notes

No schema migration required — TTL uses existing `sessions.created_at` and index from F-01.

## References

- Change identity: `context/changes/email-password-auth/change.md`
- Roadmap S-01: `context/foundation/roadmap.md`
- F-01 impl-review addendum: `context/archive/2026-06-02-minimal-auth-scaffold/plan.md`
- Auth conventions: `app/AGENTS.md`
- F-03 styling foundation: `context/archive/2026-06-07-tailwind-daisyui-setup/plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Session Hardening

#### Automated

- [x] 1.1 `bin/rspec spec/models/session_spec.rb` — existing specs pass (no regression) — ace5252
- [x] 1.2 `bin/rspec spec/requests/authentication_spec.rb` — existing specs pass (no regression) — ace5252
- [x] 1.3 `bin/rubocop` passes on touched files — ace5252

#### Manual

- [x] 1.4 Sign in, verify cookie has ~30-day expiry in browser devtools — ace5252
- [x] 1.5 `bin/rails sessions:sweep` runs without error and reports count — ace5252

### Phase 2: Auth UI & Navigation

#### Automated

- [x] 2.1 `bin/rspec spec/requests/authentication_spec.rb` — existing specs pass (no regression) — 4200b7f
- [x] 2.2 `bin/rubocop` passes on touched files — 4200b7f

#### Manual

- [x] 2.3 Auth pages render styled cards on mobile and desktop — 4200b7f
- [x] 2.4 Navbar truncates long email on narrow viewport — 4200b7f
- [x] 2.5 Duplicate registration shows generic error only — 4200b7f
- [x] 2.6 Sign out flow and guest navbar revert verified — 4200b7f

### Phase 3: Tests & Verification

#### Automated

- [x] 3.1 `bin/rspec` full suite passes — 18ba2b3
- [x] 3.2 `bin/rubocop` passes — 18ba2b3
- [x] 3.3 `bin/ci` passes — 18ba2b3

#### Manual

- [x] 3.4 End-to-end smoke: register → welcome → sign out → sign in → sign out — 18ba2b3
- [x] 3.5 Visual check: abyss theme consistent across auth pages and layout — 18ba2b3
