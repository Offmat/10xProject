<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Minimal auth scaffold

- **Plan**: context/changes/minimal-auth-scaffold/plan.md
- **Scope**: All Phases (1–3 of 3)
- **Date**: 2026-06-04
- **Verdict**: NEEDS ATTENTION
- **Findings**: 0 critical, 4 warnings, 7 observations

## Verdicts

| Dimension | Verdict |
|---|---|
| Plan Adherence | PASS |
| Scope Discipline | WARNING |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | WARNING |
| Success Criteria | PASS |

## Automated Verification

| Check | Result |
|---|---|
| `bin/rspec` | 19 examples, 0 failures |
| `bin/rubocop` | 46 files, no offenses |
| `bin/brakeman` | 0 warnings |
| `bin/rails db:prepare` | Success |
| `bin/ci` | Full suite passed (26.44s) |

## Findings

### F1 — No minimum password length validation

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/models/user.rb:2
- **Detail**: User model relies solely on `has_secure_password` defaults (presence + confirmation + 72-byte bcrypt cap). No minimum password length is enforced — a single-character password is accepted. Plan Phase 1.5 contract specifies "secure password handling"; a minimum length is a baseline security expectation. Views set `maxlength: 72` but nothing enforces a floor.
- **Fix**: Add `validates :password, length: { minimum: 8 }, allow_blank: true` to User model. `allow_blank` lets updates that don't touch the password pass through while `has_secure_password` still guards creation.
- **Decision**: FIXED

### F2 — Permanent session cookie without server-side TTL

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: app/controllers/concerns/authentication.rb:53
- **Detail**: `start_new_session_for` uses `cookies.signed.permanent` which creates a cookie with ~20-year expiry. There is no server-side session TTL or cleanup mechanism. A leaked or stolen session cookie remains valid indefinitely until the user explicitly signs out. Plan Phase 2.3 contract says "Keep session handling secure and explicit for future growth" — this leaves session lifetime unbounded.
- **Fix A ⭐ Recommended**: Replace `.permanent` with a bounded expiry
  - Strength: `cookies.signed[:session_id] = { value: session.id, httponly: true, same_site: :lax, expires: 30.days.from_now }` gives a reasonable default. Combine with a Session scope (e.g., `where('created_at > ?', 30.days.ago)`) in `find_session_by_cookie` for server-side enforcement.
  - Tradeoff: Users must re-authenticate every 30 days. May need a "remember me" checkbox later (S-01 scope).
  - Confidence: HIGH — standard Rails auth pattern used widely.
  - Blind spot: Existing sessions created with permanent cookies would still be valid; a backfill or migration needed only if existing data matters.
- **Fix B**: Document as known limitation, defer to S-01
  - Strength: Matches plan's "basics" intent — permanent is the Rails generator default. Keeps F-01 minimal.
  - Tradeoff: Sessions remain unbounded until S-01 ships. Acceptable if the app isn't publicly deployed yet.
  - Confidence: MEDIUM — safe for dev/staging but risky if the app goes live before S-01.
  - Blind spot: Timeline for S-01 delivery is unclear.
- **Decision**: ACCEPTED (Fix B — documented in plan addendum; defer TTL/cleanup/secure cookie to S-01)

### F3 — No rate limit on registration

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/controllers/users_controller.rb:1
- **Detail**: `UsersController#create` has no `rate_limit`, unlike `SessionsController` and `PasswordsController` which both use `rate_limit to: 10, within: 3.minutes`. An attacker can automate mass account creation (spam, resource exhaustion, enumeration).
- **Fix**: Add `rate_limit to: 3, within: 1.minute, only: :create, with: -> { redirect_to new_user_path, alert: 'Try again later.' }` to `UsersController`, mirroring the existing pattern.
- **Decision**: FIXED

### F4 — Unbounded sessions table growth

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: db/migrate/20260602150527_create_sessions.rb
- **Detail**: The sessions table has no `expires_at` column and no index on `created_at`. Every sign-in creates a new row; sign-out only destroys the current session. Sessions accumulate indefinitely, causing unbounded table growth. Any future cleanup query (`DELETE WHERE created_at < ?`) would require a sequential scan.
- **Fix A ⭐ Recommended**: Add index now, defer cleanup job
  - Strength: A migration adding `add_index :sessions, :created_at` is low-risk and enables future cleanup without a full table scan. The cleanup job itself can ship with S-01.
  - Tradeoff: Index adds minor write overhead per session creation.
  - Confidence: HIGH — standard practice for timestamp-based cleanup.
  - Blind spot: None significant for the index alone.
- **Fix B**: Defer entirely to S-01
  - Strength: Keeps F-01 minimal. Session volume is negligible during early development.
  - Tradeoff: If forgotten, the table grows silently until it becomes a production problem.
  - Confidence: MEDIUM — safe short-term, risky if S-01 timeline slips.
  - Blind spot: No monitoring to alert on table size.
- **Decision**: FIXED (Fix A — `index_sessions_on_created_at` migration; cleanup job deferred to S-01)

### F5 — Unplanned ActionCable auth wiring

- **Severity**: 💬 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: app/channels/application_cable/connection.rb
- **Detail**: `ApplicationCable::Connection` now authenticates WebSocket connections via session cookie lookup — mirrors the HTTP auth boundary. Not mentioned in the plan but generated by the Rails auth scaffold and consistent with auth boundary goals.
- **Fix**: Document in plan as an addendum (benign scaffold output).
- **Decision**: FIXED (plan addendum)

### F6 — Unplanned rubocop single_quotes enforcement pass

- **Severity**: 💬 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: .rubocop.yml + 12 config files (commit 5cdf6db)
- **Detail**: Separate commit enforced `EnforcedStyle: single_quotes` across 13 files outside auth scope. No behavioral change — purely style normalization to align with project convention.
- **Fix**: No action needed. Benign convention alignment.
- **Decision**: SKIPPED (acknowledged — no action)

### F7 — Unscoped routes expose dead endpoints

- **Severity**: 💬 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: config/routes.rb:2-3
- **Detail**: `resource :session` and `resources :passwords, param: :token` lack `only:` scoping, unlike `resources :users, only: %i[new create]`. This generates routes for `show`, `edit`, `update` (session) and `index`, `show`, `destroy` (passwords) that have no corresponding controller actions and would raise `AbstractController::ActionNotFound`.
- **Fix**: Scope consistently: `resource :session, only: %i[new create destroy]` and `resources :passwords, param: :token, only: %i[new create edit update]`.
- **Decision**: FIXED

### F8 — Account enumeration via registration error

- **Severity**: 💬 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/controllers/users_controller.rb:15
- **Detail**: When registration fails due to email uniqueness, Rails renders "Email has already been taken", revealing that an account exists. The password-reset flow correctly uses an ambiguous message. For MVP this is acceptable; worth hardening before public launch.
- **Fix**: Defer to S-01 UX polish, or replace the uniqueness error with a generic message.
- **Decision**: ACCEPTED (deferred to S-01 — plan addendum)

### F9 — No email format validation

- **Severity**: 💬 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/models/user.rb:5
- **Detail**: Email validation checks presence and uniqueness but not format. Invalid strings like `"notanemail"` are accepted, making password resets undeliverable and polluting the users table.
- **Fix**: Add `validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }`.
- **Decision**: FIXED

### F10 — AuthAuditLogger spec directory placement

- **Severity**: 💬 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: spec/services/auth_audit_logger_spec.rb
- **Detail**: `spec/AGENTS.md` defines `spec/services/unit/` for single-class service specs with stubs. The AuthAuditLogger spec is a unit test (stubs `Rails.logger`) but lives directly in `spec/services/` rather than `spec/services/unit/`. Also omits `type:` metadata unlike sibling specs.
- **Fix**: Move to `spec/services/unit/auth_audit_logger_spec.rb` and add `type: :service` metadata.
- **Decision**: FIXED

### F11 — Session cookie missing explicit secure flag

- **Severity**: 💬 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/controllers/concerns/authentication.rb:53
- **Detail**: The session cookie omits `secure: true`. Production has `config.force_ssl = true` which upgrades all cookies, so this is protected there. However, any non-production HTTPS environment (staging) without `force_ssl` would transmit the cookie over HTTP.
- **Fix**: Add `secure: Rails.env.production?` to the cookie options for defense-in-depth. Can be bundled with F2 fix.
- **Decision**: FIXED
