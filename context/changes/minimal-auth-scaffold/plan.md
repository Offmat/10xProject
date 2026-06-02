# Minimal auth scaffold Implementation Plan

## Overview

Implement the F-01 auth foundation for all-aBoard using Rails 8 built-in authentication as the baseline, with conventions intentionally kept close to Devise-style patterns for future optional migration. This plan includes sign-in, password reset, minimal sign-up, DB-backed session records, default route protection, and baseline auth hardening (rate limiting and auth audit logging).

## Current State Analysis

Authentication is currently absent in the app code and database schema. The repo has Rails 8.1 defaults, RSpec setup, and only a public home page route. Product and roadmap documents define email/password auth as MVP must-have and place this change before all user-facing vertical slices.

## Desired End State

A registered user can sign up, sign in, sign out, and request/reset password with Rails-native flows. Controllers default to authenticated access with explicit public allowlist. Session lifecycle is persisted in DB-backed session records. Login endpoints include baseline throttling and auth audit logs. The scaffold is test-covered and ready for S-01 UX refinement without reworking auth primitives.

### Key Discoveries:

- `context/foundation/roadmap.md` defines F-01 as User + credentials + session issuance + route protection and marks it as the first dependency.
- `context/foundation/prd.md` sets Access Control to email + password only for MVP and excludes OAuth/passwordless in v1.
- `Gemfile` currently comments out `bcrypt` and has no auth gem configured.
- `config/routes.rb` has only `root` and healthcheck routes, so protection strategy can be introduced cleanly.
- `db/schema.rb` is empty except extension setup, so auth schema can be introduced without migration conflicts.
- `spec/rails_helper.rb` auto-loads `spec/support/**/*.rb`, enabling auth test helper patterns for request specs.

## What We're NOT Doing

- OAuth providers, passwordless login, passkeys, SSO, or multi-factor auth.
- Admin roles, impersonation, invitations, or account confirmation workflows.
- Broad product-polish UX for auth pages (this remains primarily in S-01).
- Authorization policy framework rollout (Pundit/Cancancan) beyond route-level auth guards.

## Implementation Approach

Start from Rails 8 built-in auth generator conventions, then shape naming/boundary decisions to remain migration-friendly with Devise-style patterns: `User`-centric model contract, explicit `current_user` and `authenticate_user!` guard semantics, and isolated auth plumbing. Keep DB-backed session records for observability and revocation potential. Add minimal registration flow in this phase per planning decisions to validate end-to-end auth baseline early.

## Critical Implementation Details

Use `email` as the canonical app-level contract while preserving compatibility with Rails generator naming where needed. Keep the mapping explicit in one place (model/controller parameter normalization) so later migration to Devise can change internals without touching domain features.

## Phase 1: Generate and align auth foundation

### Overview

Land baseline auth components (models/controllers/routes/migrations) using Rails-native patterns, then normalize naming and guard interfaces to project conventions.

### Changes Required:

#### 1. Authentication scaffold and dependencies

**File**: `Gemfile`, `Gemfile.lock`

**Intent**: Enable required password hashing dependency and generated auth baseline dependencies.

**Contract**: `bcrypt` is present and bundled as required by `has_secure_password`-based auth.

#### 2. Auth models and migrations

**File**: `app/models/user.rb`, `app/models/session.rb`, `app/models/current.rb`, `db/migrate/*create_users*`, `db/migrate/*create_sessions*`, `db/schema.rb`

**Intent**: Introduce canonical auth data model and session lifecycle records.

**Contract**: `User` authenticates by password, `Session` belongs to `User`, and schema supports normalized email-based lookup plus password digest.

#### 3. Authentication boundary in controllers

**File**: `app/controllers/application_controller.rb`, `app/controllers/concerns/authentication.rb`

**Intent**: Establish default-protected controller behavior with explicit public exceptions.

**Contract**: Global guard behaves as `authenticate_user!`-style protection and exposes `current_user` semantics for downstream slices. `PagesController` (root route) must call `allow_unauthenticated_access` to stay public. The existing `spec/requests/pages_spec.rb` can be removed — its assertion is subsumed by the auth boundary request specs that verify public vs protected route behavior.

#### 4. Session/password endpoints and routes

**File**: `app/controllers/sessions_controller.rb`, `app/controllers/passwords_controller.rb`, `config/routes.rb`, related views/mailers

**Intent**: Provide sign-in/sign-out and password reset flows from the start.

**Contract**: Routes for session and password reset are active and wired to functional controllers/views with secure token-based reset behavior.

#### 5. Minimal sign-up path in F-01

**File**: `app/controllers/users_controller.rb` (or equivalent), registration route/view files

**Intent**: Add a minimal registration entrypoint now to validate complete auth loop before S-01 polish.

**Contract**: A new user record can be created through app-facing flow with canonical email contract and secure password handling.

### Success Criteria:

#### Automated Verification:

- Auth dependencies install cleanly via `bin/setup`.
- Database prepare/migrations succeed via `bin/rails db:prepare`.
- Auth model and request specs pass via `bin/rspec`.
- Lint and static checks pass via `bin/rubocop` and `bin/brakeman`.

#### Manual Verification:

- User can sign up, sign in, and sign out from local app flow.
- Password reset request and reset completion flow work end-to-end in development.
- Public allowlist endpoints remain reachable while protected routes redirect/deny as intended.

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase. Phase blocks use plain bullets — the corresponding `- [ ]` checkboxes for these items live in the `## Progress` section at the bottom of the plan.

---

## Phase 2: Harden authentication and observability

### Overview

Add baseline security controls requested for F-01: login throttling and auth audit trail for sign-in/sign-out lifecycle events.

### Changes Required:

#### 1. Login rate limiting

**File**: `app/controllers/sessions_controller.rb` (and supporting config/tests if needed)

**Intent**: Tune and verify the brute-force rate limiting the auth generator already provides (generator default: `rate_limit to: 10, within: 3.minutes, only: :create` on sessions and passwords controllers). Adjust thresholds if needed, integrate with audit logging, and ensure spec coverage.

**Contract**: Session creation endpoint enforces configured per-window rate limits with consistent user-visible failure behavior.

**Test caveat**: `config/environments/test.rb` uses `:null_store` for cache, which makes `rate_limit` a no-op. Rate-limit request specs must override `config.cache_store` to `:memory_store` (scoped via `around` block or RSpec metadata tag) so throttling actually fires in test.

#### 2. Auth audit logging

**File**: `app/controllers/sessions_controller.rb`, potential service/logger helper file(s)

**Intent**: Record security-relevant auth events for operational visibility.

**Contract**: Successful and failed sign-in attempts and sign-outs emit structured logs without leaking secrets.

#### 3. Session lifecycle policy basics

**File**: `app/controllers/concerns/authentication.rb`, `app/models/session.rb`

**Intent**: Keep session handling secure and explicit for future growth.

**Contract**: Session issuance/termination behavior is consistent, and session invalidation path is clearly defined on sign-out.

### Success Criteria:

#### Automated Verification:

- Rate-limit behavior is covered by request specs and passes in `bin/rspec`.
- Audit logging expectations are validated at spec level (or via stable logger assertions) in `bin/rspec`.
- Security checks pass in `bin/brakeman`.

#### Manual Verification:

- Repeated failed login attempts trigger throttling behavior as specified.
- Sign-in/sign-out actions produce expected audit log entries in development logs.

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase. Phase blocks use plain bullets — the corresponding `- [ ]` checkboxes for these items live in the `## Progress` section at the bottom of the plan.

---

## Phase 3: Test harness and migration-friendly convention lock-in

### Overview

Stabilize auth tests/helpers and codify migration-friendly conventions so future Devise adoption remains incremental instead of disruptive.

### Changes Required:

#### 1. Auth-focused test support

**File**: `spec/support/authentication_helpers.rb` (or equivalent), request/model specs under `spec/requests/` and `spec/models/`

**Intent**: Provide reusable helpers and balanced coverage for the auth scaffold.

**Contract**: Test helper APIs abstract sign-in steps; specs verify behavior without coupling to fragile internals.

#### 2. Convention alignment updates

**File**: `AGENTS.md`, `context/foundation/tech-stack.md`, any auth README notes if needed

**Intent**: Keep team/agent guidance aligned with Devise-adjacent conventions while using Rails built-ins now.

**Contract**: Guidance clearly states naming and boundary conventions (`User`, `current_user`, guard semantics, explicit session boundaries).

#### 3. CI confidence pass

**File**: CI/runtime configuration files touched by auth changes

**Intent**: Ensure scaffold is merge-ready under repo quality gates.

**Contract**: `bin/ci` passes with auth scaffold in place.

### Success Criteria:

#### Automated Verification:

- Auth helper, model, and request coverage pass in `bin/rspec`.
- Full local CI passes via `bin/ci`.

#### Manual Verification:

- A new contributor can follow documented auth conventions and locate main auth boundaries quickly.

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase. Phase blocks use plain bullets — the corresponding `- [ ]` checkboxes for these items live in the `## Progress` section at the bottom of the plan.

---

## Testing Strategy

### Unit Tests:

- `User` validations/authentication behavior, email normalization, and password constraints.
- `Session` associations and lifecycle expectations.

### Integration Tests:

- Sign-up -> sign-in -> protected route access -> sign-out flow.
- Password reset request -> token usage -> successful credential update flow.
- Throttling response behavior under repeated failed login attempts.

### Manual Testing Steps:

1. Create a new user from registration flow and verify sign-in.
2. Attempt access to protected endpoint while signed out and confirm redirect/denial.
3. Trigger password reset and complete reset link flow.
4. Generate repeated failed login attempts and verify throttle behavior and log events.

## Performance Considerations

Auth introduces additional DB reads/writes (user lookup, session record creation, audit logging). Keep queries indexed for email lookup and avoid expensive per-request auth helper work. Rate limiting thresholds should balance brute-force mitigation with normal retry behavior.

## Migration Notes

This scaffold intentionally tracks Devise-adjacent conventions. If Devise is adopted later, keep `User` as canonical model, preserve external contracts (`current_user`, guard helpers, route-level behavior), and migrate internal auth plumbing behind those boundaries to minimize downstream code changes.

## References

- Product requirements: `context/foundation/prd.md`
- Dependency order and F-01 scope: `context/foundation/roadmap.md`
- Current app routes baseline: `config/routes.rb`
- Current auth dependency baseline: `Gemfile`
- Current schema baseline: `db/schema.rb`
- Test harness baseline: `spec/rails_helper.rb`, `spec/requests/pages_spec.rb`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Generate and align auth foundation

#### Automated

- [x] 1.1 Auth dependencies install cleanly via `bin/setup` — 01df31a
- [x] 1.2 Database prepare/migrations succeed via `bin/rails db:prepare` — 01df31a
- [x] 1.3 Auth model and request specs pass via `bin/rspec` — 01df31a
- [x] 1.4 Lint and static checks pass via `bin/rubocop` and `bin/brakeman` — 01df31a

#### Manual

- [x] 1.5 User can sign up, sign in, and sign out from local app flow — 01df31a
- [x] 1.6 Password reset request and reset completion flow work end-to-end in development — 01df31a
- [x] 1.7 Public allowlist endpoints remain reachable while protected routes redirect/deny as intended — 01df31a

### Phase 2: Harden authentication and observability

#### Automated

- [x] 2.1 Rate-limit behavior is covered by request specs and passes in `bin/rspec` — 2de6664
- [x] 2.2 Audit logging expectations are validated at spec level in `bin/rspec` — 2de6664
- [x] 2.3 Security checks pass in `bin/brakeman` — 2de6664

#### Manual

- [x] 2.4 Repeated failed login attempts trigger throttling behavior as specified — 2de6664
- [x] 2.5 Sign-in/sign-out actions produce expected audit log entries in development logs — 2de6664

### Phase 3: Test harness and migration-friendly convention lock-in

#### Automated

- [x] 3.1 Auth helper, model, and request coverage pass in `bin/rspec`
- [x] 3.2 Full local CI passes via `bin/ci`

#### Manual

- [x] 3.3 A new contributor can follow documented auth conventions and locate main auth boundaries quickly
