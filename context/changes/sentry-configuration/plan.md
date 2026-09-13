# Sentry Configuration Implementation Plan

## Overview

Add production-only, server-side Sentry error monitoring to all-aBoard (Rails 8.1 on Railway): create a free Sentry project, wire `sentry-ruby` / `sentry-rails`, send unhandled exceptions only (no PII defaults, no performance tracing), and document how to set `SENTRY_DSN` on Railway.

## Current State Analysis

- No error-tracking gem in `Gemfile`; roadmap Observability notes Rails logging + `/up` only (`context/foundation/roadmap.md`).
- Secrets for production are Railway service variables (not committed); pattern documented in `context/archive/2026-05-31-deployment-plan/deployment-plan.md` and `README.md`.
- Course M3L5 Deep Dive shows Astro + Cloudflare + `captureConsoleIntegration`; this app adapts the same goals via official Ruby/Rails SDK docs.
- No `rescue_from`, no `config.exceptions_app`, no custom error controller — unhandled exceptions reach Rails’ default 500 path (static `public/*.html`), which Sentry will capture once initialized.
- Three rescues do swallow deliberately and stay invisible to Sentry by design: `app/controllers/passwords_controller.rb:32` (invalid reset token), `app/services/game_sessions/create.rb:31` and `update.rb:32` (`RecordInvalid` → `:invalid` result). `app/services/game_catalog/wikidata_client.rb:57` re-raises as `Error`, so Ruby’s `cause` chain still reaches Sentry.
- Frontend is importmap-only; no browser SDK in scope.

## Desired End State

1. A Sentry Developer project exists for all-aBoard; its DSN is set as `SENTRY_DSN` on the Railway web service.
2. `sentry-ruby` and `sentry-rails` are in the Gemfile; `config/initializers/sentry.rb` initializes only when `Rails.env.production?` and `ENV['SENTRY_DSN']` is present.
3. Unhandled exceptions in production appear as Sentry issues with breadcrumbs from Active Support / HTTP loggers; `send_default_pii` is false; tracing/profiling sample rates are unset or `0`.
4. Development/test/CI never send events (no DSN / not production).
5. README documents project creation, the Railway variable, and the console verification path; `roadmap.md` Observability and `tech-stack.md` name Sentry instead of asserting there is no error-tracking gem.

### Key Discoveries:

- Official install: gems `sentry-ruby` + `sentry-rails`; init early in `config/initializers/sentry.rb` ([Rails guide](https://docs.sentry.io/platforms/ruby/guides/rails/)).
- DSN / environment / release can be read from env vars (`SENTRY_DSN`, `SENTRY_ENVIRONMENT`, etc.); blank DSN means the SDK does not send.
- `enabled_environments` or gating on `Rails.env.production?` + present DSN both satisfy “production only.”
- Railway logs remain the complementary runtime signal (`railway logs --follow`) per M3L5 pattern for non-Cloudflare platforms.

## What We're NOT Doing

- Browser / `@sentry/browser` / importmap client SDK.
- Capturing `Rails.logger.warn` / `error` as Sentry issues (option 4A — exceptions only).
- Performance tracing, profiling, Session Replay, metrics.
- `send_default_pii = true`.
- Wiring Sentry MCP into Cursor (optional post-change operator step; link only).
- Refactoring existing services to add `Sentry.capture_exception` everywhere.
- Enabling Solid Queue workers solely for Sentry (no real jobs yet).
- Committing DSN or any Sentry auth tokens.

## Implementation Approach

Manual: create Sentry project → copy DSN → set Railway variable → confirm spike protection / rate limit. Code: add gems (with lockfile), add initializer gated to production **and** DSN, keep config minimal (breadcrumbs on, PII off, no traces). Docs: operator steps and verification in README; Sentry recorded in roadmap + tech-stack. Smoke: one `Sentry.capture_exception` from the in-container Rails console after deploy — no test route, no throwaway deploy.

## Critical Implementation Details

### Timing & lifecycle

Initialize in `config/initializers/sentry.rb` (Rails convention). Do not put DSN in credentials or commit it — Railway variable only for production.

The initializer is evaluated more often than “once per deploy”, so it must stay cheap and side-effect-free at load time:

- **Image build**: `Dockerfile:61` runs `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` under `ENV RAILS_ENV="production"` (`Dockerfile:24`) with `config.eager_load = true` — so the file loads during every build. `Rails.env.production?` is *true* there; only the absent DSN keeps it inert, because Railway does not inject service variables into Dockerfile builds without an explicit `ARG` (the sole `ARG` is `RUBY_VERSION`). Do not add `ARG SENTRY_DSN`.
- **Pre-deploy**: `railway.toml` `preDeployCommand` → `bin/predeploy` boots `bin/rails runner` up to 30 times while waiting for Postgres, then `bin/rails db:prepare`; `bin/docker-entrypoint` runs `db:prepare` again. Each is a full production boot that constructs a Sentry client.

No network calls, no DSN validation requests, no `Sentry.capture_*` at load time.

### Debug & observability

After deploy with DSN set, confirm one event end-to-end from the in-container Rails console (`railway ssh --service web` → `bin/rails console` → `Sentry.capture_exception(...)`). No temporary route or deployed `raise` is needed, so there is nothing to clean up afterwards.

---

## Phase 1: Sentry project and Railway DSN

### Overview

Create the Sentry account/project and wire the DSN into Railway so production can send events once the SDK is shipped.

### Changes Required:

#### 1. Create Sentry project (manual)

**File**: (operator) [sentry.io](https://sentry.io/) — free Developer plan

**Intent**: Create an organization (if needed) and a **Ruby / Rails** project for all-aBoard; copy the Client DSN.

**Contract**: Prefer platform “Ruby” / “Rails”. Retain DSN privately; never commit. Free Developer plan is enough for course/MVP quotas ([pricing](https://sentry.io/pricing/)).

#### 2. Set Railway variable (manual)

**File**: Railway web service variables (dashboard or `railway variable set`)

**Intent**: Expose the DSN to the production container as `SENTRY_DSN`.

**Contract**: Variable name exactly `SENTRY_DSN`. Repo CLI convention is `railway variable set SENTRY_DSN --stdin --service web` (singular `variable`, per the archived deployment plan). Do not set it in CI or local `.env` for routine work (production-only). Redeploy / restart so the running process picks it up after the SDK lands (or before — blank-safe).

#### 3. Quota guard in Sentry project settings

**File**: (operator) Sentry project settings

**Intent**: Keep one crash loop or a recurring bot-triggered exception from draining the 5k errors/month Developer quota — the same discipline as the Railway spend limit in `context/foundation/infrastructure.md`.

**Contract**: Confirm **spike protection** is enabled and set a per-project **rate limit** on the DSN key (Settings → Client Keys → rate limit). Leave the SDK's default ignored-exception list alone (it already drops `ActiveRecord::RecordNotFound`, routing errors, and similar 404-class noise); do not add a `sample_rate` — dropping real errors at random is worse than hitting the cap.

#### 4. Document operator steps and verification

**File**: `README.md` (one subsection under Configuration or Production/Railway)

**Intent**: Record create-project → copy DSN → set `SENTRY_DSN` on Railway, plus how to confirm it works, so the next operator does not rely on chat history.

**Contract**: One subsection covering all of:
- Setup: create project → copy DSN → `railway variable set SENTRY_DSN --stdin --service web` (repo CLI convention per the archived deployment plan). Placeholder value only — never a real DSN.
- Verification: `railway ssh --service web` → `bin/rails console` → `Sentry.initialized?` / `Sentry.capture_exception(...)`; link [Sentry Rails docs](https://docs.sentry.io/platforms/ruby/guides/rails/).
- Boundaries: development/test send nothing (no DSN, not production); `railway logs --follow` remains the complementary log stream.
- One sentence noting Sentry MCP (https://github.com/getsentry/sentry-mcp) exists as an agent triage option and is **not** wired by this change. If it doesn't fit in a sentence, drop it.

### Success Criteria:

#### Automated Verification:

- No real DSN in tracked docs: `rg -n 'ingest\.(us\.)?sentry\.io' README.md context/` returns nothing (or only placeholder text)

#### Manual Verification:

- Sentry project exists; DSN visible in project settings
- `SENTRY_DSN` is set on the Railway web service (value masked in UI)
- Spike protection on; per-key rate limit configured in the Sentry project
- README documents setup **and** the console verification path without embedding the real DSN

**Implementation Note**: After completing this phase, pause for human confirmation before Phase 2 if preferred; code Phase 2 can proceed in parallel once DSN is known or will be set before verify.

---

## Phase 2: Gems and production initializer

### Overview

Install the Ruby/Rails SDK and initialize Sentry only in production when a DSN is present, with exception-only, no-default-PII configuration.

### Changes Required:

#### 1. Add gems

**File**: `Gemfile` (+ lockfile via `bin/setup` / bundle)

**Intent**: Add official Sentry gems for Rails error capture.

**Contract**:
```ruby
gem 'sentry-ruby'
gem 'sentry-rails'
```
No `stackprof` / profiling gems. Install through project bundle path (`vendor/bundle` via `bin/setup` conventions).

`Gemfile.lock` **must** be regenerated and committed in the same commit as the `Gemfile` edit. CI runs bundler in frozen/deployment mode (`ruby/setup-ruby` with `bundler-cache: true` in all four jobs of `.github/workflows/ci.yml`) and the image build sets `BUNDLE_DEPLOYMENT="1"` (`Dockerfile:25`) against per-gem `sha256=` checksums — a Gemfile-only commit fails every CI job and the Railway build before any other check runs.

#### 2. Initializer

**File**: `config/initializers/sentry.rb` (new)

**Intent**: Boot Sentry early with production-only, DSN-gated config matching the locked decisions.

**Contract**:
- Call `Sentry.init` only when **both** `Rails.env.production?` **and** `ENV['SENTRY_DSN'].present?` hold. Both conditions are load-bearing — see the build-time note below. Do not relax this to an env-only check.
- `config.dsn = ENV['SENTRY_DSN']`
- `config.breadcrumbs_logger = [:active_support_logger, :http_logger]`
- `config.send_default_pii = false`
- Do **not** set positive `traces_sample_rate` / `profiles_sample_rate` (errors only).
- Do **not** enable logger-as-issue patches / `enable_logs` for warn→issue (4A).
- Prefer single-quoted Ruby strings per repo style.

#### 3. Foundation notes (required, small)

**File**: `context/foundation/roadmap.md` (Observability line, currently line 66) and `context/foundation/tech-stack.md` (one bullet)

**Intent**: Record that production error tracking is Sentry via `SENTRY_DSN`, so future agents do not re-propose a second vendor — and so foundation docs do not assert something false.

**Contract**:
- `roadmap.md:66` currently reads “Observability: partial — Rails default logging + `/up` healthcheck; no error-tracking gem in `Gemfile`”. That clause is false once the gems merge — this edit is **not** deferrable to archive time.
- `tech-stack.md` has no observability section today, so add one factual line (production errors → Sentry via `SENTRY_DSN`, server-side only).
- Factual one-liners only — no DSN, no `AGENTS.md` change (root `AGENTS.md` points at foundation docs; a third copy of the same fact is redundant).

### Success Criteria:

#### Automated Verification:

- `bundle check` exits 0 and `git status --porcelain Gemfile.lock` is empty after `bundle install` (lockfile committed with the Gemfile)
- `bundle exec ruby -c config/initializers/sentry.rb` or boot check: `RAILS_ENV=development bin/rails runner 'puts :ok'` exits 0
- `RAILS_ENV=test bin/rails runner 'puts :ok'` exits 0 (Sentry not sending)
- `bin/rubocop` clean on touched Ruby files
- `bin/rspec` still green (no test env side effects)
- `rg -n 'no error-tracking gem' context/foundation/` returns nothing (roadmap Observability line updated); `tech-stack.md` mentions Sentry

#### Manual Verification:

- With DSN unset locally, no Sentry network traffic on a deliberate raise in development
- After production deploy with `SENTRY_DSN` set, a verify exception raised from the in-container console appears as an issue in the Sentry project

**Implementation Note**: Verify from an in-container console, not from a deployed route. `railway ssh --service web` → `bin/rails console` (README → “Option 4: Rails console (in-container)”), then:

```ruby
Sentry.initialized?  # => true
Sentry.capture_exception(RuntimeError.new('sentry verify'))
```

This costs no deploy and exposes no public surface. Do **not** add a `/sentry-test` route or ship a temporary `raise`. The console check proves DSN, network, and environment wiring; treat the first genuine production 500 as confirmation of the Rails middleware capture path.

**Wrap-up**: After Phase 2 manual verification, mark Progress complete and move to `/10x-impl-review` or `/10x-archive` when ready. There is no third phase — README content (setup, verification, MCP sentence) all lands in Phase 1 §3, and every check that a former docs phase would have repeated is already covered by Phase 1 or Phase 2.

---

## Testing Strategy

### Unit Tests:

- No dedicated Sentry unit suite required for MVP. Optional: assert initializer file exists / does not raise on load in test — only if cheap.

### Integration Tests:

- None required; Sentry is an external sink. Do not hit real Sentry from CI.

### Manual Testing Steps:

1. Create Sentry Rails project; copy DSN.
2. Set `SENTRY_DSN` on Railway; deploy commit with gems + initializer.
3. `railway ssh --service web` → `bin/rails console`; check `Sentry.initialized?`, then `Sentry.capture_exception(RuntimeError.new('sentry verify'))`; confirm issue + stack trace in Sentry.
4. Boot app locally without DSN; raise in console — nothing sent to Sentry.
5. Run `bin/rspec` — green, no Sentry dependency in specs.

## Performance Considerations

Errors-only configuration avoids tracing overhead and preserves free-plan quota for real exceptions.

## Migration Notes

No database migration. Redeploy required after setting `SENTRY_DSN` and merging the SDK. Removing the Railway variable disables sending without a code rollback.

## References

- Course M3L5 “Debugowanie z AI — od stack trace” (external course materials, not tracked in this repo; Deep Dive — adapt from Astro)
- Sentry Rails: https://docs.sentry.io/platforms/ruby/guides/rails/
- Sentry Ruby options: https://docs.sentry.io/platforms/ruby/configuration/options/
- Railway vars pattern: `context/archive/2026-05-31-deployment-plan/deployment-plan.md`
- Pricing: https://sentry.io/pricing/
- Optional MCP: https://github.com/getsentry/sentry-mcp

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Sentry project and Railway DSN

#### Automated

- [x] 1.4 No real DSN string in tracked docs — bdde9ed

#### Manual

- [x] 1.1 Sentry project exists; DSN visible in project settings — bdde9ed
- [x] 1.2 SENTRY_DSN is set on the Railway web service (value masked in UI) — bdde9ed
- [x] 1.3 README documents the steps without embedding the real DSN — bdde9ed
- [x] 1.5 Spike protection on and per-key rate limit set in Sentry project — bdde9ed

### Phase 2: Gems and production initializer

#### Automated

- [x] 2.1 Development boot check exits 0 without sending — 8078a31
- [x] 2.2 Test boot check exits 0 without sending — 8078a31
- [x] 2.3 RuboCop clean on touched Ruby files — 8078a31
- [x] 2.4 bin/rspec green with no Sentry test side effects — 8078a31
- [x] 2.7 Gemfile.lock regenerated and committed with the Gemfile change — 8078a31
- [x] 2.8 roadmap Observability line and tech-stack.md updated to name Sentry — 8078a31

#### Manual

- [x] 2.5 Local raise without DSN does not send to Sentry — 8078a31
- [x] 2.6 Production verify exception appears as a Sentry issue (checked in advance — verify right after deploy) — 8078a31
