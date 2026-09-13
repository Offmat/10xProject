<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Sentry Configuration Implementation Plan

- **Plan**: `context/changes/sentry-configuration/plan.md`
- **Mode**: Deep
- **Date**: 2026-09-13
- **Verdict**: REVISE → SOUND after fixes
- **Findings**: 0 critical, 5 warnings, 2 observations (all fixed)

## Verdicts

| Dimension | Verdict (at review) |
|-----------|---------------------|
| End-State Alignment | WARNING |
| Lean Execution | WARNING |
| Architectural Fitness | PASS |
| Blind Spots | WARNING |
| Plan Completeness | WARNING |

## Grounding

7/8 paths ✓ — `materials/main_course/m3l5-debugowanie-z-ai-od-stack-trace.md` does not exist (no `materials/` dir, not gitignored, nothing matching `m3l5` tracked). Symbols ✓ — no Sentry gem, no `SENTRY_DSN`, no monitoring initializer anywhere in the repo yet. brief↔plan ✓. Progress format ✓ (well-formed phases + Automated/Manual split).

SDK config cross-checked against current Sentry Rails docs: `dsn`, `breadcrumbs_logger`, `send_default_pii = false`, and omitting `traces_sample_rate` are all correct; a blank DSN genuinely disables sending (`traces_sample_rate` default is `nil`, `send_default_pii` defaults to false).

Codebase verification (sub-agent, file:line evidence) confirmed: the initializer is evaluated at image build (`Dockerfile:61` `assets:precompile` under `RAILS_ENV=production`, `eager_load = true`) and on every pre-deploy boot (`railway.toml` → `bin/predeploy` retries `bin/rails runner` up to 30×, plus `bin/docker-entrypoint`); one app service (`web`); frozen bundler in all four CI jobs and `BUNDLE_DEPLOYMENT=1` in the Dockerfile; WebMock blocks external HTTP in specs (`spec/support/webmock.rb:3`).

## Findings

### F1 — Production verify step has no concrete, safe trigger

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM
- **Dimension**: End-State Alignment
- **Location**: Phase 2 Implementation Note, Phase 3 Manual Verification, Progress 2.6 / 3.2
- **Detail**: The one criterion proving the change works was undefined ("Sentry's documented verify path or a short-lived production raise"). No staging environment exists, so a short-lived raise means two Railway deploys with a publicly reachable raise in between.
- **Fix**: Use the in-container console path already documented at `README.md:150-165` — `railway ssh --service web` → `bin/rails console` → `Sentry.initialized?` / `Sentry.capture_exception(RuntimeError.new('sentry verify'))`. No route, no extra deploy; first genuine 500 confirms the middleware path.
- **Decision**: FIXED (Phase 2 Implementation Note, Debug & observability, Manual Testing Steps step 3)

### F2 — Gemfile.lock regeneration is not a verification step; frozen bundler makes it a hard failure

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW
- **Dimension**: Plan Completeness
- **Location**: Phase 2 §1, Phase 2 Success Criteria
- **Detail**: All four CI jobs use `ruby/setup-ruby` with `bundler-cache: true` (frozen/deployment mode when a lockfile exists) and `Dockerfile:25` sets `BUNDLE_DEPLOYMENT="1"` against per-gem `sha256=` checksums. A Gemfile-only commit fails every CI job and the Railway build before any planned check runs.
- **Fix**: Explicit contract note plus automated criterion (`bundle check` + clean `git status --porcelain Gemfile.lock`) and Progress step 2.7.
- **Decision**: FIXED

### F3 — Foundation/doc updates optional-worded and absent from Progress; roadmap.md:66 becomes false

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW
- **Dimension**: Plan Completeness
- **Location**: Phase 2 §3, Phase 3 §2
- **Detail**: Hedged three ways ("and/or", "if appropriate", "can wait until implement/archive") with no criterion or Progress step, including the edit to `context/foundation/roadmap.md:66` which asserts "no error-tracking gem in `Gemfile`".
- **Fix**: Roadmap + tech-stack edits are now required Phase 2 §3 content with automated criterion (`rg -n 'no error-tracking gem' context/foundation/` empty) and Progress step 2.8; `AGENTS.md` explicitly de-scoped; MCP pointer reduced to one required sentence or dropped.
- **Decision**: FIXED

### F4 — Phase 3 mostly re-verifies Phase 2

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW
- **Dimension**: Lean Execution
- **Location**: Phase 3 (all), Progress 3.1-3.4
- **Detail**: 3.2 duplicated 2.6, 3.4 duplicated 2.1/2.5, 3.1 overlapped 1.3, and 3.3 (`railway logs --follow` still usable) cannot be affected by this change. Phase 3's only real content was one README paragraph plus the MCP link.
- **Fix A ⭐ (applied)**: Folded README setup + verification + MCP sentence into Phase 1 §4, deleted Phase 3, dropped 3.3; added Phase 1 automated step 1.4 (no real DSN in tracked docs). Brief phase table updated to two phases.
- **Fix B**: Keep Phase 3, delete duplicated criteria only.
- **Decision**: FIXED via Fix A

### F5 — Initializer runs at Docker build time and repeatedly during pre-deploy

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM
- **Dimension**: Blind Spots
- **Location**: Phase 2 §2 Contract, Critical Implementation Details → Timing & lifecycle
- **Detail**: `Dockerfile:61` boots Rails in production mode with eager loading during every image build, so `Rails.env.production?` is true at build time — only the absent DSN keeps it inert, and Railway does not inject service variables into Dockerfile builds without an explicit `ARG`. The plan's "or equivalent early return" permitted an env-only guard. Pre-deploy boots Rails up to 30+ times per deploy.
- **Fix**: Both guard conditions now mandatory; added a Timing & lifecycle subsection documenting build-time and pre-deploy evaluation with file:line evidence, "do not add `ARG SENTRY_DSN`", and no network work at load time.
- **Decision**: FIXED

### F6 — Free-plan quota assumption had no mitigation

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: Blind Spots
- **Location**: plan-brief.md Open Risks; Phase 1
- **Detail**: 5k errors/month with no spike-protection or rate-limit step; a crash loop or recurring bot-triggered exception could drain it. Same class as the unset Railway spend limit in `infrastructure.md`.
- **Fix**: New Phase 1 §3 (operator step) — confirm spike protection, set per-key rate limit, keep SDK default ignored exceptions, no `sample_rate`. Progress step 1.5; brief assumption reworded.
- **Decision**: FIXED

### F7 — Two inaccuracies in Current State / References

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: Plan Completeness
- **Location**: Current State Analysis, References, change.md Notes
- **Detail**: (a) `materials/main_course/m3l5-…md` does not exist. (b) "Almost no swallowed-exception patterns" understated three deliberate rescues: `app/controllers/passwords_controller.rb:32`, `app/services/game_sessions/create.rb:31`, `app/services/game_sessions/update.rb:32` (plus `wikidata_client.rb:57`, which re-raises so the `cause` chain survives).
- **Fix**: Course reference marked external in plan and `change.md`; Current State rewritten to name the three rescues as knowingly invisible to Sentry.
- **Decision**: FIXED
