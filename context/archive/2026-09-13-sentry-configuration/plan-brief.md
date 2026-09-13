# Sentry Configuration — Plan Brief

> Full plan: `context/changes/sentry-configuration/plan.md`

## What & Why

Add production error monitoring so unhandled Rails exceptions on Railway show up in Sentry with stack traces and breadcrumbs. Supports the M3L5 reactive-debug workflow (evidence from monitoring + platform logs) on this Rails stack instead of the lesson’s Astro/Cloudflare sample.

## Starting Point

No error-tracking gem; observability is Rails logs + `/up`. Production secrets already live as Railway service variables. Frontend is importmap-only; no swallowed-error campaign is in scope.

## Desired End State

Production (with `SENTRY_DSN` set) reports unhandled exceptions to a free Sentry Developer project. Development/test/CI send nothing. Operator steps are documented in README; MCP setup remains optional and out of code.

## Key Decisions Made

| Decision | Choice | Why |
| -------- | ------ | --- |
| Sentry account | Plan includes creating project + DSN | Operator must own the free Developer project |
| Client SDK | Server-only (`sentry-ruby` / `sentry-rails`) | MVP; importmap browser SDK deferred |
| Environments | Production only when DSN present | Avoid noise and accidental local/CI traffic |
| Event types | Unhandled exceptions only (4A) | Free-plan quota; less warn noise |
| Performance | Errors only | No tracing/profiling overhead |
| PII | `send_default_pii = false` | Safer default for course/MVP |

## Scope

**In scope:** Create Sentry project; Railway `SENTRY_DSN`; gems + initializer; README/light foundation notes; production verify.

**Out of scope:** Browser SDK; logger-warn→issues; tracing/replay; MCP install; blanket `capture_exception` refactors; committing secrets.

## Architecture / Approach

Sentry Ruby SDK initializes in `config/initializers/sentry.rb` when `Rails.env.production?` and `ENV['SENTRY_DSN']` is set. Rails middleware captures unhandled exceptions; breadcrumbs come from Active Support / HTTP loggers. Railway remains the live log stream (`railway logs --follow`).

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Project + Railway DSN | Sentry project, `SENTRY_DSN`, README setup + verification docs | DSN leaked into git if mishandled |
| 2. Gems + initializer + verify | Production-gated SDK config, foundation notes, end-to-end issue confirmation | Init too broad (dev/test) if gating wrong; missing `Gemfile.lock` breaks CI and the Railway build |

**Prerequisites:** Railway project access; ability to create a free Sentry account.
**Estimated effort:** ~1 short session (manual Sentry/Railway + small gem/initializer PR).

## Open Risks & Assumptions

- Free Developer quota (5k errors/mo) is enough if we stay exceptions-only — guarded by Sentry spike protection plus a per-key rate limit (Phase 1), not by SDK-side sampling.
- No need for Active Job-specific extras until real Solid Queue jobs exist.

## Success Criteria (Summary)

- Production exception → Sentry issue with stack trace.
- Local/test without DSN → no events sent.
- DSN never committed; README explains setup.
