<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Capybara E2E Prep

- **Plan**: `context/changes/capybara-e2e-prep/plan.md`
- **Scope**: Phases 1–5 (all)
- **Date**: 2026-09-09
- **Verdict**: NEEDS ATTENTION
- **Findings**: 0 critical, 8 warnings, 2 observations
- **Triage**: 9 fixed, 1 skipped (F1)

## Triage outcome

| Finding | Decision |
|---|---|
| F1 — Unguarded first Stimulus click | SKIPPED — cold-runner flake risk on the required gate remains open |
| F2 — Headed manual rows rubber-stamped | FIXED (Fix A) |
| F3 — CI Chrome fallback can't install | FIXED (Fix A) |
| F4 — `js_errors: false` | FIXED |
| F5 — Missing `type: :system` degrades silently | FIXED |
| F6 — Ferrum logger handle leak | FIXED |
| F7 — `sign_out` no-op / password kwarg | FIXED |
| F8 — Unpinned gems | FIXED |
| F9 — Raw cookie vs escaped | FIXED |
| F10 — Seed and smoke polish | FIXED |

Post-triage verification: `CI=true bin/rspec spec/` → 202 examples, 0 failures;
`bin/rubocop spec/ Gemfile config/ci.rb` → 39 files, no offenses;
`bin/rails zeitwerk:check` → All is good.

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | WARNING |
| Success Criteria | WARNING |

### Verification run (2026-09-09)

| Check | Result |
|---|---|
| `bundle show capybara` / `cuprite` | capybara 3.40.0, cuprite 0.18 under `vendor/bundle` |
| `bin/rspec spec/models spec/requests spec/services` | 197 examples, 0 failures |
| `CI=true bin/rspec spec/system/` | 2 examples, 0 failures |
| `bin/rubocop` (7 touched Ruby files) | no offenses |
| `bin/rails zeitwerk:check` | All is good |
| `git diff -- .cursor/skills/10x-e2e/` | empty (course skill untouched) |
| `git diff -- app/` | empty (production auth untouched) |

Plan Adherence note: every "Changes Required" item verified MATCH. One benign
deviation from the plan's stated *approach* (not its contract): the skill fork
shipped ~28 KB against the plan's budgeted "~51 KB full copy" — all contract
items (PLAN→GENERATE→REVIEW→VERIFY, eligibility gate, Progress ritual, five
anti-patterns, seed path, Capybara-not-Playwright setup gate, derivation note)
survived; upstream's "E2E guidelines", "File placement", "If you get stuck", and
"Other stacks" sections have no counterpart.

Scope Discipline note: all "What We're NOT Doing" guardrails held. Extras in the
diff (`spec/system/smoke_auth_spec.rb`, `context/foundation/roadmap.md`,
`Gemfile.lock`, `change.md`, plan Progress flips) are each sanctioned by the plan
or normal bookkeeping.

## Findings

### F1 — First Stimulus click in the seed has no readiness guard

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: spec/system/game_sessions/player_fidelity_spec.rb:25
- **Detail**: `click_button '+ Add player'` is the first JS-dependent action in the spec. `app/javascript/controllers/index.js` uses `eagerLoadControllersFrom` over importmap (async module graph), and the button is `type="button"` whose only behavior is `data-action="click->nested-form#add"`. A click landing before the controller registers is a silent no-op. Capybara retries *finders*, not *actions*, so line 26's `have_css(count: 1)` polls for 5s and fails without ever re-clicking. Lines 22–23 (`select` / `fill_in`) need no JS, so they don't warm the controller up. This is the classic cold-CI-runner flake, and it sits on a hard required gate.
- **Fix A ⭐ Recommended**: Have `nested_form_controller.js` set a dataset marker in `connect()`, then wait on `expect(page).to have_css('[data-nested-form-ready]')` before the first click.
  - Strength: Deterministic; `context/foundation/interactive-forms.md` judgement item 9 already names "exposing a `connected` value for test sync" as the sanctioned pattern here.
  - Tradeoff: Touches a production Stimulus controller for a test concern — `spec/AGENTS.md` says prefer test-side fixes and ask before editing `app/`.
  - Confidence: HIGH — removes the race rather than widening the window.
  - Blind spot: Other Stimulus controllers driven by future system specs would each need the same marker.
- **Fix B**: Add a `spec/support` helper that polls `page.evaluate_script("!!window.Stimulus")` before the first interaction.
  - Strength: Pure test-side; `app/javascript/controllers/application.js:7` already exposes `window.Stimulus`.
  - Tradeoff: Proves Stimulus *booted*, not that this specific controller connected — narrower race remains.
  - Confidence: MEDIUM — strictly better than today, not airtight.
  - Blind spot: Haven't measured how much of the window it actually closes on a cold runner.
- **Decision**: SKIPPED

### F2 — Headed-mode manual rows marked done, but headed mode is unsupported

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Success Criteria
- **Location**: context/changes/capybara-e2e-prep/plan.md:121, 400, 414 vs spec/support/capybara.rb:13
- **Detail**: `spec/support/capybara.rb:13-17` documents headed mode as *intentionally not supported* (Chrome 152 + Ferrum 0.18 "Failed to find browser context"; Cursor process coalition aborts headed NSApplication). Yet Progress row 1.5 ("Headed cookie sign-in reaches authenticated page without login UI") and row 2.5 ("Optional headed Stimulus add-row validation") are both `[x]`, and Phase 1's Manual Verification still reads "With `HEADLESS=0` (or Cuprite headed flag)…". The manual criteria as written could not have been executed. The underlying verification was almost certainly done another way (the smoke spec asserts authenticated chrome and saves a screenshot), but the plan never records the substitution.
- **Fix A ⭐ Recommended**: Amend Phase 1's Manual Verification in the plan to state the headless + `tmp/screenshots` substitution and cite the Chrome/Ferrum reason, leaving 1.5/2.5 checked.
  - Strength: The verification intent *was* met by other means (`spec/system/smoke_auth_spec.rb:10-12` asserts authenticated chrome; criterion 1.6 covers it); this makes the record honest without pretending work is undone.
  - Tradeoff: Edits a plan whose Progress is already closed out with SHAs.
  - Confidence: HIGH — the substitute evidence exists on disk and passes.
  - Blind spot: Row 2.5's Stimulus add-row observation has no equivalent artifact; it was optional.
- **Fix B**: Uncheck 1.5 and 2.5 and leave them as known-unverifiable on this toolchain.
  - Strength: Strictest reading of "never check manual rows without human confirmation".
  - Tradeoff: Leaves the change permanently unable to reach a complete Progress state, which blocks the archive ritual.
  - Confidence: MEDIUM — depends on how strictly the archive gate reads Progress.
  - Blind spot: None significant.
- **Decision**: FIXED via Fix A — Phase 1 Manual Verification amended in plan.md to record the headless substitution and its Chrome/Ferrum reason; rows 1.5 and 2.5 stay checked.

### F3 — CI Chrome fallback branch cannot actually install Chrome

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: .github/workflows/ci.yml:113-125
- **Detail**: The fallback runs `sudo apt-get install -y google-chrome-stable` without adding Google's APT repository or signing key, so it resolves only if the repo is already configured. On today's `ubuntu-latest` Chrome is preinstalled and the first branch always wins, so the fallback is dead code — but the day GitHub drops Chrome from the image, the required `test` gate fails with `Unable to locate package` instead of self-healing. That is precisely the scenario the plan's "install step if `google-chrome` missing" was meant to cover. The `chromium-browser` / `chromium` branches only print a version and never tell Ferrum where the binary is.
- **Fix A ⭐ Recommended**: Replace the shell block with a pinned `browser-actions/setup-chrome@v1` step.
  - Strength: Removes the untested branch entirely and gives a pinnable Chrome version, which also contains the Chrome-vs-Ferrum incompatibility already documented in `spec/support/capybara.rb:13`.
  - Tradeoff: Adds a third-party action to a workflow that currently uses only first-party ones.
  - Confidence: HIGH — standard approach for Cuprite/Ferrum on GHA.
  - Blind spot: Haven't checked whether the action's Chrome path is auto-discovered by Ferrum or needs `BROWSER_PATH`.
- **Fix B**: Keep the shell block but add Google's signing key and apt source in the fallback before installing.
  - Strength: No new action dependency; preserves the existing prefer-preinstalled structure.
  - Tradeoff: More shell to maintain, and still untested until the day it's needed.
  - Confidence: MEDIUM — correct in principle, unverifiable in practice on the current image.
  - Blind spot: None significant.
- **Decision**: FIXED via Fix A — shell block replaced with `browser-actions/setup-chrome@v2` (`install-dependencies: true`); the RSpec step now passes `BROWSER_PATH` from the action's `chrome-path` output. Blind spot closed: `ferrum/browser/command.rb:38` reads `ENV['BROWSER_PATH']` before PATH detection, so no `spec/support/capybara.rb` change was needed.

### F4 — `js_errors: false` suppresses the exact failure class the specs exist to catch

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: spec/support/capybara.rb:22
- **Detail**: With `js_errors: false`, a broken `nested_form_controller` or `player_fields_controller` surfaces as `Unable to find field "Guest name" that is not disabled` after a 5s timeout rather than as the actual JS exception. The plan anticipated this and set it deliberately, with the explicit note "revisit only after a clean baseline run" (plan line ~86). The baseline is now clean — both system specs pass green under `CI=true` — so the revisit condition the plan itself set has been met.
- **Fix**: Flip to `js_errors: true`; if Turbo/importmap emits benign navigation noise, scope the suppression to the affected examples rather than globally.
  - Strength: Turns silent locator timeouts into named JS exceptions, which is the whole point of a browser gate on Stimulus risk.
  - Tradeoff: May surface pre-existing console noise and cost one debugging pass.
  - Confidence: HIGH — the plan pre-authorized this once baseline was green.
  - Blind spot: Haven't run the suite with `js_errors: true` to see what noise exists.
- **Decision**: FIXED — flipped to `js_errors: true`. Blind spot closed: `CI=true bin/rspec spec/system/` re-run green (2 examples, 0 failures), no console noise surfaced, so no per-example suppression was needed. This follows rather than deviates from the plan, which authorized the revisit "after a clean baseline run".

### F5 — A system spec missing `type: :system` degrades silently in three ways

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: spec/rails_helper.rb:64
- **Detail**: `config.infer_spec_type_from_file_location!` is commented out (the plan deliberately kept it off to avoid retroactively re-typing every spec directory). The consequence for a future file dropped under `spec/system/` without explicit metadata: no `driven_by`, no pinned/shared connection pool, and `system_spec?` (`spec/support/authentication_helpers.rb:37`) returns false so `sign_in_as` takes the **request** branch and calls `post session_path` from a non-integration group. `spec/AGENTS.md` documents the requirement, which helps humans but not the failure mode.
- **Fix**: Scope the inference to just this directory instead of enabling it globally — `config.define_derived_metadata(file_path: %r{/spec/system/}) { |meta| meta[:type] ||= :system }`.
  - Strength: Gets the safety of inference for `spec/system/` while preserving the plan's reason for keeping the global switch off.
  - Tradeoff: One more config line; slightly less explicit than requiring the metadata in each file.
  - Confidence: HIGH — standard rspec-rails idiom, no effect on other directories.
  - Blind spot: None significant.
- **Decision**: FIXED — added a scoped `define_derived_metadata(file_path: %r{/spec/system/})` block in `spec/rails_helper.rb` directly beneath the commented-out global inference, with a comment naming the three silent degradations. System specs re-run green.

### F6 — Ferrum logger opens a file handle per example and never closes it

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: spec/support/capybara.rb:26-29
- **Detail**: The `File.open(...)` sits inside `config.before(:each, type: :system)`, so it runs per example. Only the first handle is ever used — Rails' `before_teardown` calls `Capybara.reset_sessions!` (reset, not quit), so the browser and its original logger persist for the whole run — and every subsequent example leaks a descriptor. The handle also isn't `sync`'d, so a hard-killed process loses the log tail, which is exactly the timeout case the artifact upload exists for.
- **Fix**: Open the log once at file load outside the hook, set `.sync = true`, and reuse the memoized handle.
- **Decision**: FIXED — hoisted to a `CUPRITE_CI_LOGGER` constant opened once at load with `sync = true`. Verified `CI=true bin/rspec spec/system/` green and `tmp/ferrum-stderr.log` still populated (612 KB).

### F7 — `sign_out` can silently no-op and never destroys the Session row

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: spec/support/authentication_helpers.rb:14-22, 4-11
- **Detail**: Three related soft spots in the shared helper. (1) `page.driver.remove_cookie('session_id') if page.driver.respond_to?(:remove_cookie)` silently no-ops on any driver lacking the method, so `sign_out; sign_in_as(other)` would stay signed in as the first user and fail somewhere confusing — the guard is dead code today since `cuprite-0.18` defines it. (2) Unlike production's `terminate_session`, the system branch never destroys the `Session` row, so the cookie-invalidation half is untested. (3) `sign_in_as(user, password:)` keeps the `password:` kwarg but the system branch ignores it, so `sign_in_as(user, password: 'wrong')` would silently succeed and pass for the wrong reason. The request branch asserts its outcome; the system branch asserts nothing.
- **Fix**: Drop the `respond_to?` guard so a driver change fails loudly, destroy the user's sessions in the system branch, assert `have_link('Sign in')` after the visit, and raise `ArgumentError` if a non-default `password:` reaches the system branch.
- **Decision**: FIXED — all three. `sign_out_system` extracted: destroys the `@system_session` record (mirroring production's `terminate_session`), removes the cookie unguarded, and asserts `have_link('Sign in')`. `sign_in_as` raises `ArgumentError` when a non-default `password:` reaches the system branch. Verified with a throwaway probe spec (since no committed spec exercises `sign_out` in a browser): `sign_out` changed `Session.count` by −1 and dropped authenticated chrome, and the password guard raised. Probe deleted; full `CI=true bin/rspec spec/` green (202 examples).

### F8 — `capybara` and `cuprite` are unpinned against a fully pinned Gemfile

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: Gemfile:78-79
- **Detail**: Every other dev/test gem carries a constraint (`webmock '~> 3.26'`, `rspec-rails '~> 8.0'`, `shoulda-matchers '~> 7.0'`, `factory_bot_rails '~> 6.5'`); these two do not. It matters more than usual because `spec/support/capybara.rb:13-15` documents a concrete Chrome 152 / Ferrum 0.18 incompatibility, and an unpinned `cuprite` lets a routine `bundle update` move `ferrum` and reintroduce it. `Gemfile.lock` + CHECKSUMS keep CI reproducible today, which is why this is a warning rather than higher. The plan's contract literally wrote the bare gem lines, so this is plan-compliant but convention-divergent.
- **Fix**: `gem 'capybara', '~> 3.40'` and `gem 'cuprite', '~> 0.18'`.
- **Decision**: FIXED — both pinned. `bundle install` re-resolved cleanly; the only `Gemfile.lock` change is the two `DEPENDENCIES` lines, with resolved versions unchanged.

### F9 — Cookie injected raw where production escapes it (latent)

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: spec/support/authentication_helpers.rb:46
- **Detail**: `set_cookie` injects the raw signed value, while Rails' real write path escapes via `Rack::Utils.set_cookie_header!` and unescapes on read (`+` → space). This works today only by arithmetic accident: the signed jar's verifier is built without `url_safe: true`, but Base64 of pure-ASCII JSON can emit `+`/`/` only when a source byte is `>`, `?`, `~`, or DEL — none of which occur in the session payload. Switching `cookies_serializer` to `:marshal`, moving to encrypted cookies, or putting non-ASCII in the payload would start producing intermittent failures in exactly the silent-anonymous mode the plan warned about. Verified correct as-is: salt `'signed cookie'`, purpose `cookie.session_id`, raw round-trip all confirmed against a live test-env console.
- **Fix**: Wrap in `Rack::Utils.escape(jar[:session_id])` to mirror production's write path byte for byte.
- **Decision**: FIXED — wrapped in `Rack::Utils.escape` with a comment naming the `parse_cookies_header` unescape. System specs green; the smoke spec's authenticated-chrome assertion confirms the cookie still takes.

### F10 — Seed and smoke spec polish

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: spec/system/smoke_auth_spec.rb:14-15; spec/system/game_sessions/player_fidelity_spec.rb:1, 29, 50
- **Detail**: Four small things, none of which weaken the risk coverage. (1) The smoke spec saves `tmp/screenshots/smoke_auth.png` unconditionally on *success*, adding a CDP round-trip per green run and putting a success screenshot into the CI failure artifact bundle. (2) `choose 'Friend'` (line 29) is a no-op — `_player_fields.html.erb` renders that radio pre-checked, so no `change` event fires and `player-fields#toggle`'s friend branch is never exercised. (3) `GameSession.order(:id).last` (line 50) isn't scoped to the creator; safe under transactional isolation but `where(creator: logger).order(:id).last!` is stronger. (4) `player_fidelity_spec.rb` is the only one of 24 spec files carrying `# frozen_string_literal: true`, and `smoke_auth_spec.rb` from the same series omits it.
- **Fix**: Gate the screenshot on an env var or drop it; either remove `choose 'Friend'` or add a Guest→Friend switch-back case that actually fires the toggle; scope the `GameSession` lookup to the creator; align the magic comment either way.
- **Decision**: FIXED — all four. (1) Unconditional screenshot dropped from the smoke spec; Rails' own `ScreenshotHelper` already captures to `tmp/screenshots` on failure, which is what the CI artifact step collects. (2) The no-op `choose 'Friend'` became a Guest→Friend round-trip that genuinely fires `player-fields#toggle`'s friend branch and proves the abandoned guest name does not survive the switch back — a leak would push `participants.size` to 4 or make `find_by!(user: friend)` raise. (3) `GameSession.where(creator: logger).order(:id).last!`. (4) Stray `# frozen_string_literal: true` removed to match the other 23 spec files.
