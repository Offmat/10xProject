# Email/Password Auth — Plan Brief

> Full plan: `context/changes/email-password-auth/plan.md`

## What & Why

Ship S-01 — the first user-visible slice of all-aBoard. Players need to create an account, log in, and log out before friend circles or session logging (S-02, S-03). F-01 built the auth backend; this change adds polished UI and closes security deferrals from impl review.

## Starting Point

F-01 delivered working `UsersController`, `SessionsController`, `PasswordsController`, DB-backed sessions, rate limiting, audit logging, and request specs — but auth views are bare HTML, the navbar always shows Sign in/Sign up, and sessions use permanent cookies with no TTL or sweep.

## Desired End State

Users interact with styled daisyUI auth pages, see their email and a Sign out button when logged in, get a personalized welcome on the home page, and operate under 30-day session expiry with operator-schedulable stale-session cleanup. Registration failures never reveal whether an email is taken.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
|----------|--------|------------------|--------|
| Page scope | Full auth suite + welcome home | Consistent UX across password reset; home proves auth state | Plan |
| Session TTL | 30 days (cookie + server scope) | Matches F-01 impl-review example; reasonable for hobby app | Plan |
| Remember me | Skip | Simplest path; not in roadmap | Plan |
| Registration errors | Generic on all failures | Prevents email enumeration | Plan |
| Navbar (authenticated) | Truncated email + Sign out | Clear identity without dropdown complexity | Plan |
| Session cleanup | `bin/rails sessions:sweep` rake task | No job infra yet; index already exists | Plan |
| Staging secure cookies | `ENV['FORCE_SECURE_COOKIES']` | No staging Rails env; opt-in for HTTPS deploys | Plan |
| Testing | Request specs + sweep unit test | Covers behavior without brittle CSS assertions | Plan |

## Scope

**In scope:** 30-day session TTL + active scope + sweep rake task; secure-cookie env flag; daisyUI restyle of sign-in, sign-up, forgot/reset password; generic registration errors; navbar auth state + sign-out; welcome home message; extended request/model specs.

**Out of scope:** Remember me, OAuth/MFA, `/dashboard` route, ActiveJob sweep, view/CSS class specs, display-name field, password-reset logic changes.

## Architecture / Approach

Preserve F-01's `Authentication` concern and controller layout. Add `Session::LIFETIME`, `active` scope, and `sweep` on the model; update cookie setting and `find_session_by_cookie` (plus Action Cable) to honor TTL. Introduce a shared `_auth_card` partial for all auth views. Branch layout nav and home page on `authenticated?`. Three phases: harden sessions → ship UI → extend tests and run CI.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|------------------|----------|
| 1. Session hardening | 30-day TTL, active lookup, sweep task, secure-cookie flag | Action Cable must use same active scope as HTTP |
| 2. Auth UI & navigation | daisyUI pages, nav sign-out, welcome home, anti-enumeration | Generic errors must not leak model messages |
| 3. Tests & verification | Full spec coverage + CI green | Request specs need built Tailwind asset in test env |

**Prerequisites:** F-01 (done), F-03 Tailwind/daisyUI (done).

**Ops:** Schedule `bin/rails sessions:sweep` daily on Railway (or equivalent cron). Set `FORCE_SECURE_COOKIES=true` on HTTPS staging if cookies fail to persist.

**Estimated effort:** ~2 sessions across 3 phases.

## Open Risks & Assumptions

- Request specs rendering layout may require prebuilt `tailwind.css` (known from F-03); run Tailwind build before spec if missing.
- Sweep task only helps if ops schedules it — document but don't automate in this slice.
- Email local-part greeting may look odd for plus-addressed emails — acceptable for MVP.

## Success Criteria (Summary)

- User can sign up, sign in, and sign out through styled pages with correct navbar state.
- Duplicate registration shows a generic error; sessions expire after 30 days.
- `bin/ci` passes; manual smoke test confirms welcome home and sign-out flow.
