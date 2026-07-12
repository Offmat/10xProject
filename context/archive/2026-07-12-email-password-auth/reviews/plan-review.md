<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Email/Password Auth Implementation Plan

- **Plan**: context/changes/email-password-auth/plan.md
- **Mode**: Deep
- **Date**: 2026-07-12
- **Verdict**: REVISE
- **Findings**: [1 critical] [2 warnings] [0 observations]

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | PASS |
| Architectural Fitness | PASS |
| Blind Spots | WARNING |
| Plan Completeness | FAIL |

## Grounding

13/13 paths ✓, 6/6 symbols ✓, brief↔plan ✓

## Findings

### F1 — Progress↔Phase mismatch: Phase 2 manual criteria consolidated

- **Severity**: ❌ CRITICAL
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 2 — Manual Verification / Progress
- **Detail**: Phase 2 Success Criteria lists 4 manual verification bullets: (1) styled cards, (2) navbar truncates email, (3) duplicate registration generic error, (4) sign-out flow. But Progress Phase 2 Manual has only 3 items — 2.4 merges bullets 2 and 3 into one line: "Navbar truncates long email; duplicate registration shows generic error only." This violates the 1:1 mapping convention between Success Criteria bullets and Progress checklist items. /10x-implement will fail to parse a Progress section that doesn't match the phase body.
- **Fix**: Split Progress item 2.4 into two items (2.4 and 2.5) and renumber current 2.5 to 2.6.
- **Decision**: FIXED — split 2.4 into 2.4 + 2.5, renumbered 2.5 → 2.6

### F2 — Phase 1 & 2 automated criteria reference specs created in Phase 3

- **Severity**: ⚠️ WARNING
- **Impact**: 🔬 HIGH — architectural stakes; think carefully before deciding
- **Dimension**: Plan Completeness
- **Location**: Phases 1, 2, and 3
- **Detail**: Phase 1 automated criteria (1.1 session model specs, 1.2 expired session rejection) and Phase 2 automated criteria (2.1 nav, welcome, generic registration) describe spec examples that are only created in Phase 3 (items 1 and 2). Today `session_spec.rb` has only a `belongs_to` test; `authentication_spec.rb` has no nav-content, welcome-text, or expired-session assertions. Running `bin/rspec` after Phase 1 or 2 passes vacuously — the criteria's described coverage doesn't exist until Phase 3. The plan's phase-gate model ("pause for verification after each phase") breaks down because automated verification is hollow until Phase 3.
- **Fix A ⭐ Recommended**: Move spec writing into each phase — Phase 1 writes session model specs and expired-session request specs alongside the code; Phase 2 writes nav/welcome/registration specs alongside the views. Phase 3 reduces to a CI-pass gate and manual smoke test. Each phase becomes self-verifiable.
  - Strength: Each phase is self-verifiable; consistent with TDD/red-green-refactor.
  - Tradeoff: Phases 1 and 2 grow slightly; Phase 3 shrinks.
  - Confidence: HIGH — the plan already lists the exact spec examples per phase; they just need to move up.
  - Blind spot: None significant.
- **Fix B**: Keep tests in Phase 3 but reword Phase 1/2 criteria to "existing specs don't regress" only, removing references to not-yet-written examples.
  - Strength: Minimal plan restructuring; preserves "ship code, then lock in tests" cadence.
  - Tradeoff: Phases 1 and 2 have only manual verification and "existing specs don't regress" as automated criteria — weaker phase gates.
  - Confidence: MEDIUM — works if the implementer understands the criteria are "don't break existing tests" not "new tests pass."
  - Blind spot: Implementer might miss bugs that only show up in the deferred spec examples.
- **Decision**: FIXED via Fix B — reworded Phase 1/2 automated criteria to "existing specs pass (no regression)"; spec writing stays in Phase 3

### F3 — Generic registration errors suppress all validation feedback

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Blind Spots
- **Location**: Phase 2 — Generic registration failure (item 5)
- **Detail**: The plan sets `@registration_error` to a single generic string on ALL save failures (Critical Implementation Details: "even for password confirmation mismatches"). This prevents email enumeration but also hides safe-to-show password validation errors: "password too short", "confirmation doesn't match." Only the "Email has already been taken" error reveals whether an email is registered. Password length and confirmation mismatch errors carry no enumeration risk. A user who enters a 3-char password or mismatched confirmation gets "Unable to create account" with no guidance — likely to retry blindly or abandon.
- **Fix A ⭐ Recommended**: Filter errors — suppress only email-related messages. On failed save, check if errors are email-attribute-only; if so, set generic `@registration_error`. Otherwise, show password validation errors normally. Preserves anti-enumeration while giving actionable feedback for password issues.
  - Strength: Preserves anti-enumeration while giving actionable feedback for password issues. Better UX with identical security posture.
  - Tradeoff: Slightly more logic in `UsersController#create` (check whether errors are email-only vs. password-related).
  - Confidence: HIGH — the email uniqueness error is a known Rails validation message; filtering by attribute is straightforward.
  - Blind spot: Future model validations on other attributes would need to be classified as safe-to-show or not.
- **Fix B**: Keep blanket generic error, add client-side hints via HTML5 validation attributes (minlength on password fields).
  - Strength: Simplest server logic; client-side validation catches most password format issues before submit.
  - Tradeoff: Client-side validation can be bypassed; doesn't help with API clients; adds complexity.
  - Confidence: MEDIUM — client-side helps but doesn't replace server-side feedback for edge cases.
  - Blind spot: Importmap + Stimulus overhead for form validation not assessed.
- **Decision**: FIXED via Fix A — plan updated to filter errors by attribute; only email-related errors get generic message; password errors shown normally
