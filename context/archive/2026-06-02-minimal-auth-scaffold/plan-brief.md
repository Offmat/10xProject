# Minimal auth scaffold — Plan Brief

> Full plan: `context/changes/minimal-auth-scaffold/plan.md`

## What & Why

This change establishes the authentication foundation required by roadmap F-01: user credentials, session issuance, and route protection. It uses Rails built-in auth as the implementation base, while keeping conventions close to Devise-style patterns so a future migration stays incremental rather than disruptive.

## Starting Point

The current app has no auth implementation: routes are public except healthcheck/root, schema has no user/session tables, and `bcrypt` is not enabled. PRD and roadmap both define email/password auth as must-have baseline before any vertical feature slices.

## Desired End State

Users can sign up, sign in, sign out, and reset password on a secure baseline. Protected-by-default controller boundaries are in place with explicit public allowlist. Session lifecycle is DB-backed and observable. Auth endpoints include rate limiting and audit logging, and the scaffold is test-covered and CI-ready for S-01 expansion.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Password reset scope | Include in F-01 | Keeping generator reset flow avoids immediate auth debt and aligns with secure baseline defaults. | Plan |
| Canonical identifier naming | `email` app-level contract | This keeps naming closer to common Rails/Devise conventions while allowing internal mapping. | Plan |
| Session persistence strategy | DB-backed session records | Improves lifecycle control and future revocation/audit capability with low added complexity now. | Plan |
| Route protection model | Protect by default with explicit public skips | Safer default reduces chance of unintentionally public endpoints as features grow. | Plan |
| Sign-up boundary | Include minimal sign-up in F-01 | Gives true end-to-end auth validation now while leaving UX polish for S-01. | Plan |
| Testing depth | Balanced model + request + helper coverage | Provides strong regression protection without overfitting generated internals. | Plan |
| Security hardening in F-01 | Add rate limiting and auth audit logging | Delivers baseline brute-force defense and operational visibility from day one. | Plan |

## Scope

**In scope:** User/session schema, sign-up/sign-in/sign-out/reset flows, global auth guard boundary, login throttling, auth audit logging, balanced RSpec coverage, CI readiness.

**Out of scope:** OAuth/passwordless/passkeys, admin auth features, MFA, full auth UX polish, broad authorization framework rollout.

## Architecture / Approach

Use Rails 8 auth generator structure as the baseline and keep auth plumbing isolated behind stable app-facing boundaries (`current_user`, guard helpers, explicit sign-in/out semantics). Treat session management and security controls as first-class infrastructure in this scaffold so later slices can focus on product behavior.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Generate and align auth foundation | Core models/controllers/routes/migrations + minimal sign-up | Scope creep into full S-01 UX |
| 2. Harden authentication and observability | Rate limiting + auth audit logging + session lifecycle tightening | Overly aggressive throttling hurting normal retries |
| 3. Test harness and migration-friendly convention lock-in | Reusable auth test helpers + docs/convention alignment + CI confidence | Drifting into implementation-specific tests |

**Prerequisites:** Rails app baseline present (already true), PostgreSQL running locally, `bin/setup` environment healthy.
**Estimated effort:** ~2-3 implementation sessions across 3 phases.

## Open Risks & Assumptions

- Choosing minimal sign-up in F-01 may overlap with S-01 if UX boundaries are not kept strict.
- Rate-limit thresholds require tuning to avoid false positives in normal usage.
- Email contract normalization must remain explicit to avoid confusion between internal and public naming.

## Success Criteria (Summary)

- Auth foundation exists and works end-to-end (sign-up/sign-in/sign-out/reset) with protected-by-default route boundaries.
- Baseline hardening is active (login throttling + auth audit logging) and behavior is verified in tests and manual checks.
- Local quality gates pass (`bin/ci`) with migration-friendly auth conventions documented for future work.
