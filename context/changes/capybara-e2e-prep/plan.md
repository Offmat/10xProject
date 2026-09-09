# Capybara E2E Prep Implementation Plan

## Overview

Stand up Capybara system specs with Cuprite for all-aBoard, ship one seed fidelity test that protects test-plan risks #1–#2 (multi-player form POST), wire Chrome in CI, and add a project skill `/10x-e2e-capybara` forked from the course `/10x-e2e` so the lesson skill stays untouched while agents get Capybara idioms.

## Current State Analysis

- RSpec is live (`bin/rspec`, GHA `test` job); **no** Capybara / Cuprite / Selenium; **no** `spec/system/`.
- Auth is cookie-based: `cookies.signed[:session_id]` → `Session.active` (`app/controllers/concerns/authentication.rb`). Request helper `sign_in_as` POSTs `session_path` and is included only for `type: :request`.
- Browser risk lives in Stimulus nested players: `nested_form_controller.js`, `player_fields_controller.js`, `app/views/game_sessions/_form.html.erb` / `_player_fields.html.erb`.
- `context/foundation/test-plan.md` Phase 1 (fidelity) and Phase 4 (CI floor) are **not started**; §6.3–6.4 TBD.
- Archived decision (`context/archive/2026-09-06-e2e-tooling-choice/analysis.md`): Capybara primary; do not adopt Playwright Node suite.
- Course skill `.cursor/skills/10x-e2e/` and `.cursor/rules/10x-course.mdc` assume Playwright; must remain the lesson artifact.

### Key Discoveries

- rspec-rails system specs: `type: :system`, `driven_by`, transactional fixtures OK (no DatabaseCleaner).
- Cuprite (Ferrum/CDP) is pure Ruby, fits solo MVP; faster than Selenium; exposes Hotwire race conditions that demand state waits (not `sleep`).
- System sign-in without UI: inject signed `session_id` cookie after a domain-establishing `visit` (Lewis Buckley / Rails SessionTestHelper pattern), matching `start_new_session_for`.
- GHA `ubuntu-latest` typically has Chrome; Cuprite needs `browser_options: { 'no-sandbox' => nil }` in CI/containers.
- Factories already exist for users, games, friendships, game_sessions — seed can compose them.

## Desired End State

- `bin/rspec spec/system` runs Cuprite-backed system specs locally and in CI.
- One seed system spec proves: after a real browser multi-player submit (friend + guest), persisted participants match what the UI submitted; unique data + cleanup; auth via extended `sign_in_as` (no login UI).
- Agents use `/10x-e2e-capybara` for browser-risk work; `/10x-e2e` unchanged for course/Playwright contexts.
- `test-plan.md` §4/§6.3–6.4 and Phase 4 reflect reality; Phase 1 system portion credited (request-oracle tightening may remain open); `interactive-forms.md` points at system-spec floor.

## What We're NOT Doing

- Installing Playwright as a Node E2E suite, Playwright MCP/CLI as required CI tooling, Stagehand, Cypress, or vision/VLM gates.
- Patching or replacing the course skill `.cursor/skills/10x-e2e/` in place.
- Full auth / password-reset browser coverage (test-plan §7 out).
- Tightening *all* request-spec param oracles from test-plan Phase 1 — only the multi-player create example is strengthened here (Phase 2 item 3); the rest stays an optional follow-up.
- Parallel system-spec sharding, multi-browser matrix, pixel snapshots.
- Changing production auth/session cookie format.
- DatabaseCleaner (rely on Rails system-spec transactions).

## Implementation Approach

Five phases: (1) gems + Cuprite + system auth helper, (2) fidelity seed spec, (3) CI Chrome floor, (4) new skill fork with Capybara references, (5) foundation/docs sync. Prefer label/button/text finders, falling back to row-scoped attribute finders where the markup has no usable label (see Phase 2); wait on Capybara matchers; unique guest names / timestamps; assert DB participants after submit, not flash alone.

## Critical Implementation Details

**System `sign_in_as`:** Create a `Session` for the user, `visit` a same-origin URL first (e.g. `new_session_path` or root), then set the signed `session_id` cookie through the Cuprite driver so `find_session_by_cookie` succeeds. Keep request-spec `post session_path` path unchanged. Include the helper for both `type: :request` and `type: :system`, branching on the example type or on `respond_to?(:page)`.

Do **not** hand-roll the signed value. Rails derives it from three things that must all match production — the `'signed cookie'` salt off `secret_key_base`, the JSON serializer (`config.load_defaults 8.1`), and the purpose metadata `cookie.session_id` — and a mismatch fails silently: the browser is simply anonymous, `require_authentication` redirects to `new_session_path`, and the seed dies on a confusing locator error. Generate through a real jar instead:

```ruby
jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
jar.signed[:session_id] = session.id
page.driver.set_cookie('session_id', jar[:session_id])
```

Set the cookie only after a same-origin `visit` so the driver has a domain; match `Capybara.server_host` and path `/`.

**Hotwire / Cuprite:** Prefer `have_button` / `have_field` / `have_select` with Capybara's retry waits. After Stimulus add-row, wait for the new row to appear before filling. Do not use `sleep`. Disable or avoid flaky CSS transitions if clicks miss (test env CSS if needed).

**CI Chrome:** After Tailwind build and `db:test:prepare`, ensure Chromium/Chrome is available for Cuprite (install step if `google-chrome` missing). Pass Cuprite `browser_options` when `ENV['CI']`.

**Skill fork:** Copy structure from `.cursor/skills/10x-e2e/` into `.cursor/skills/10x-e2e-capybara/`; remap discovery (no Playwright config required), seed path → `spec/system/…`, runner → `bin/rspec path`, locators → Capybara, auth → `sign_in_as` / cookie. Add a short “derived from 10x-e2e / M3L4” note; leave upstream skill pristine.

---

## Phase 1: Wire Capybara + Cuprite + system auth

### Overview

Add browser-test gems and configure system specs to run headless Cuprite with a shared `sign_in_as` that works for system examples without the login UI.

### Changes Required

#### 1. Test gems

**File**: `Gemfile` (group `:test`)

**Intent**: Add Capybara and Cuprite so system specs can drive headless Chrome via CDP.

**Contract**: `gem 'capybara'` and `gem 'cuprite'` under `:test`; install via `bin/setup` / bundle into `vendor/bundle`.

#### 2. Cuprite driver registration

**File**: `spec/support/capybara.rb` (new)

**Intent**: Register Cuprite as the system driver with sensible waits, screen size, `js_errors: false`, headless default, and CI `no-sandbox`. `js_errors: true` would raise on any page JS error, turning unrelated Turbo/importmap console noise into seed failures and muddying the deliberate-break check (step 2.2); revisit only after a clean baseline run.

**Contract**: `driven_by :cuprite` (or registered name) in `RSpec.configure` `before(type: :system)`; `Capybara.default_max_wait_time` ≥ 5; `ignore_hidden_elements` true; server silent Puma if needed.

`config.infer_spec_type_from_file_location!` is commented out (`spec/rails_helper.rb`) and `.rspec` requires only `spec_helper`, so living under `spec/system/` buys a file nothing: every system spec must `require 'rails_helper'` and declare `type: :system` explicitly or the `before` hook never fires and `visit` is undefined. Keep inference off — turning it on would retroactively re-type every existing spec directory.

#### 3. System auth helper

**File**: `spec/support/authentication_helpers.rb`

**Intent**: Extend `sign_in_as` / `sign_out` so system specs authenticate via signed session cookie without filling the login form.

**Contract**: Include helpers for `type: :system` as well as `:request`. System path creates `Session`, builds the signed cookie value through `ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})` (see Critical Implementation Details), and sets it via Cuprite `set_cookie` after a same-origin visit. Request path remains `post session_path` + `follow_redirect!`.

#### 4. Spec layout docs touch (minimal)

**File**: `spec/AGENTS.md`

**Intent**: Document `spec/system/` and that system specs use Cuprite + `sign_in_as` (full cookbook comes in Phase 5).

**Contract**: Add `spec/system/` row to Layout table; one hard-rule or auth bullet pointing at system cookie sign-in; note that system specs must `require 'rails_helper'` and carry explicit `type: :system`.

### Success Criteria

#### Automated Verification

- `bundle show capybara` and `bundle show cuprite` resolve under project bundle path
- A minimal smoke `spec/system` example that only `sign_in_as` + `visit` a protected path returns green under `bin/rspec` (may live temporarily or as prelude to Phase 2 seed)
- Existing request specs still pass: `bin/rspec spec/requests/`
- RuboCop clean on touched Ruby files: `bin/rubocop` on changed paths
- Smoke example asserts it is *authenticated* — a protected path renders authenticated chrome, not the sign-in form (a green run alone does not prove the cookie took)

#### Manual Verification

- With `HEADLESS=0` (or Cuprite headed flag), confirm cookie sign-in lands on an authenticated page without typing email/password

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 2.

---

## Phase 2: Seed fidelity system spec

### Overview

Add the canonical seed system spec that exercises the session form’s Stimulus add/remove and asserts persisted participants match the submitted friend + guest (test-plan risks #1–#2).

### Changes Required

#### 1. Seed system spec

**File**: `spec/system/game_sessions/player_fidelity_spec.rb` — canonical seed path; Phase 4's skill and Phase 5's docs both point here, so do not rename it

**Intent**: One independently runnable example: authenticated logger with accepted friend and a catalog game opens new session, adds friend row + guest row via UI, submits, then asserts DB (and visible show/index) contains both players with expected identities/scores. Unique guest name (`Guest #{timestamp}`). Cleanup or unique data so re-runs do not collide.

**Contract**: `type: :system`; name binds to risk (e.g. “submitted players persist after log session”); label finders where the markup supports them (`click_button 'Log Session'`, `fill_in 'Your score'`, `select … from: 'Game'`), **row-scoped** finders inside each player row (see below); **no** `sleep`; assert participant set, not only flash.

**Player-row locators (the markup does not support bare label finders):** in `_player_fields.html.erb` the Score label carries no `for` and does not wrap its input, the friend `<select>` has no id/label/placeholder, and guest name is reachable only by its placeholder — so `fill_in 'Score'` cannot resolve, and the Friend/Guest radios repeat per row. The form also renders zero rows initially (`@player_rows = []`) and `nested_form_controller.js` seeds `#index = Date.now()`, so field-name indices are not predictable and must never be hardcoded. Scope every row interaction instead:

```ruby
click_button '+ Add player'
within(all('[data-nested-form-row]').last) do
  choose 'Guest'                                   # fires player-fields#toggle
  fill_in 'Guest name', with: guest_name           # placeholder locator
  find('[name$="[score]"]').fill_in with: 20
end
```

Order matters: the guest fieldset ships `disabled` (rows default to type `friend`), so `choose 'Guest'` must run before the guest name field is fillable. Wait on the new row via the Capybara matcher, not `sleep`. Prefer provenance comment linking to `test-plan.md` risks #1–#2.

#### 2. Factories / fixtures only as needed

**File**: `spec/factories/*` (only if gaps)

**Intent**: Ensure factories can build logger + accepted friendship + game without inventing new domain rules.

**Contract**: Reuse existing factories; do not change production models for the test. The `:accepted` trait on `friendship` is required explicitly — the factory default is `:pending`, and a pending friend never reaches `@friends`.

#### 3. Strengthen the multi-player request oracle

**File**: `spec/requests/game_sessions_spec.rb`

**Intent**: Close the HTTP half of Risk #1. The multi-player example currently asserts `game_session_participants.count == 3` — which `test-plan.md` §2 names as the anti-pattern for this exact risk — so it cannot tell three correct participants from three wrong ones.

**Contract**: Replace the count assertion with a participant-set assertion (per row: identity via `user` or `guest_name`, plus `score` and `status`), lifting the pattern from `spec/services/unit/game_sessions/create_spec.rb`. Touch only that assertion — no new examples, no restructuring.

### Success Criteria

#### Automated Verification

- `bin/rspec spec/system/` green (seed included)
- Deliberate-break check documented in Progress manual step: temporarily weaken persistence or assertion target, confirm red, revert (do not commit the break)
- Multi-player request example asserts the participant set (identity/score/status), not `count`: `bin/rspec spec/requests/game_sessions_spec.rb`
- Full non-system suite still green: `bin/rspec spec/models spec/requests spec/services`

#### Manual Verification

- Read the seed: confirms it would fail if a player row were dropped on save
- Headed run once if useful to validate Stimulus add-row UX under Cuprite

**Implementation Note**: Pause for manual confirmation before Phase 3.

---

## Phase 3: CI browser floor

### Overview

Make GitHub Actions able to run Cuprite system specs as part of the existing `test` job so the fidelity seed is a required gate.

### Changes Required

#### 1. GHA test job

**File**: `.github/workflows/ci.yml`

**Intent**: Ensure Chrome/Chromium is available and system specs run in CI with the same `bin/rspec spec/` invocation (or explicit include).

**Contract**: Add a step to install/verify Chrome if needed on `ubuntu-latest`; set `CI=true` (already typical); Cuprite picks up `no-sandbox` from Phase 1 config. Do not mark system specs `allow_failure`. Add an `if: failure()` step uploading `tmp/screenshots` (Capybara writes failure screenshots there) and Ferrum stderr as a GHA artifact — a hard gate with no artifact is close to undebuggable from the job log alone.

#### 2. Local CI parity

**File**: `config/ci.rb` (the Chrome prerequisite note lands in root `AGENTS.md` in Phase 5, item 4)

**Intent**: Keep `bin/ci` / `bin/rspec` as the single local path that includes system specs once gems are installed.

**Contract**: No separate optional system job; one required path.

### Success Criteria

#### Automated Verification

- CI workflow includes browser availability for Cuprite and still validates structurally (job keeps Postgres, Tailwind, `db:test:prepare`, `bin/rspec`)
- Locally: `CI=true bin/rspec spec/system/` green with Cuprite headless
- System specs run as a required gate — no `allow_failure` / `continue-on-error` on the `test` job
- Workflow uploads `tmp/screenshots` + Ferrum stderr as an artifact on failure (`if: failure()`)
- Lefthook/zeitwerk unchanged and still pass on commit

#### Manual Verification

- After push (or `act` if used), confirm GHA `test` job installs browser deps and runs the seed green

**Implementation Note**: Pause for manual confirmation before Phase 4.

---

## Phase 4: Skill `10x-e2e-capybara`

### Overview

Create a project skill forked from `/10x-e2e` with a full Capybara reference map, and point this repo’s course rule at it for all-aBoard work without modifying the upstream lesson skill.

### Changes Required

#### 1. New skill package

**Files**: `.cursor/skills/10x-e2e-capybara/SKILL.md` + `references/`

**Intent**: Preserve PLAN→GENERATE→REVIEW→VERIFY, eligibility gate, Progress ritual, and anti-pattern discipline; swap Playwright discovery/syntax for Capybara + `bin/rspec`.

**Contract**: Reference map (copy then remap):

| Reference | Capybara adaptation |
|-----------|---------------------|
| `seed-test-pattern.md` | Points at Phase 2 seed path; Capybara finders; Cuprite notes |
| `e2e-quality-rules.md` | `find_button`/`have_button`/`fill_in`/`have_content`; no `sleep`; isolation; `sign_in_as`; **scoped-attribute finders inside `within` are the sanctioned exception** when markup lacks a usable label (Phase 2 rationale) — a blanket "no CSS" rule would be unfollowable here |
| `e2e-anti-patterns.md` | Same five names; examples in Capybara |
| `e2e-prompt-template.md` | “Write a system spec…”; real vs mocked boundaries for Rails |
| `browser-driven-generation.md` | Prefer reading running app + accessibility-ish labels / DOM via Capybara or manual explore; Playwright CLI/MCP optional-only, not required |

`SKILL.md` description triggers: `e2e`, `capybara`, `system spec`, browser risk on this Rails app. Setup stops if Capybara/Cuprite missing (not if Playwright missing).

**Why a full copy rather than a stub that delegates to `10x-e2e`:** upstream is a course artifact `10x-cli` can refresh, so a self-contained fork keeps this repo's E2E guidance stable. Accepted cost: ~51 KB duplicated, and the tool-agnostic parts (workflow, anti-pattern names, prompt template) may drift from the lesson version over time.

#### 2. Course / agent pointer

**Files**: `.cursor/rules/10x-course.mdc` and/or root `AGENTS.md`

**Intent**: For this repository, prefer `/10x-e2e-capybara`; keep `/10x-e2e` as the unmodified course Playwright skill.

**Contract**: Short note in the M3L4 rule block: all-aBoard → `10x-e2e-capybara`; do not delete the Playwright hard rules for learners who still use `/10x-e2e` elsewhere.

### Success Criteria

#### Automated Verification

- Skill directory exists with `SKILL.md` and all five remapped references
- No edits under `.cursor/skills/10x-e2e/` (diff empty for that tree)
- `bin/rails zeitwerk:check` still passes (skill is not Ruby)

#### Manual Verification

- Skim skill: discovery gate mentions Cuprite/`spec/system`; seed path matches Phase 2 file
- Course rule / AGENTS pointer prefers `/10x-e2e-capybara` for this app while `/10x-e2e` stays the course skill

**Implementation Note**: Pause for manual confirmation before Phase 5.

---

## Phase 5: Foundation sync

### Overview

Update foundation and agent docs so the written strategy matches the shipped floor.

### Changes Required

#### 1. Test plan

**File**: `context/foundation/test-plan.md`

**Intent**: Record Capybara+Cuprite, fill §6.3–6.4 cookbook from the seed, mark Phase 4 done (or equivalent), advance Phase 1 for the system half / note remaining request-oracle work if any.

**Contract**: §4 stack row updated with versions/notes + `checked:` date; AI-native still not required; Phase table Status/Change folder references `capybara-e2e-prep` where appropriate; §5 gate “system specs…” required.

#### 2. Interactive forms guide

**File**: `context/foundation/interactive-forms.md`

**Intent**: Point authors at the system-spec floor and when to add browser coverage for Stimulus forms.

**Contract**: Add a short subsection or Related bullet: system specs via Cuprite; seed pattern path; judgement item 7 remains judgement but now has a concrete floor to extend.

#### 3. Spec AGENTS polish

**File**: `spec/AGENTS.md`

**Intent**: Finalize system-spec conventions (finders, waits, auth, one-test-per-risk budget).

**Contract**: Align with skill quality rules; link to `test-plan.md` §6.3.

#### 4. Root AGENTS.md prerequisite

**File**: `AGENTS.md`

**Intent**: Put the Chrome/Chromium requirement where developers actually look — the "Build, test, and development" section owns test commands, and without a browser `bin/rspec` now fails for reasons unrelated to the developer's change.

**Contract**: One line under Build/test/development: system specs need Chrome/Chromium locally (same spirit as the existing `pg_isready` Postgres note). No other AGENTS.md restructuring.

### Success Criteria

#### Automated Verification

- `context/foundation/test-plan.md` §4 stack row, §6.3–6.4 cookbook, and Phase 1/4 status updated
- `context/foundation/interactive-forms.md` points at the system-spec floor and the seed path
- `spec/AGENTS.md` documents system-spec conventions (finders, waits, auth)
- Root `AGENTS.md` states the local Chrome/Chromium prerequisite for system specs

#### Manual Verification

- Read test-plan §3–§6: Phase 4 closed; Phase 1 status honest about system vs request-oracle remainder
- Docs do not present a Playwright Node suite as the project default; no broken internal references

**Implementation Note**: After Phase 5, change is ready for `/10x-impl-review` / archive when Progress is complete.

---

## Testing Strategy

### Unit / request

- Do not replace existing request specs; the system seed is additive.
- One existing oracle is strengthened in place (Phase 2 item 3): the multi-player create example moves from a participant count to a participant set.
- Optional follow-up (out of scope): the remaining request oracles that mirror Stimulus param shape.

### System

- One fidelity seed (Phase 2); CI runs it (Phase 3).
- Budget: do not add page-per-test coverage in this change.

### Manual Testing Steps

1. Headed Cuprite: sign-in cookie → new session form → add friend + guest → submit → verify UI + DB.
2. Deliberate break: drop a participant in create path or weaken assertion → red → revert.
3. Re-run seed twice back-to-back: no unique-constraint / leftover collisions.

## Performance Considerations

Cuprite is faster than Selenium but still minutes-scale in CI; keep system count minimal. Prefer cookie auth over UI login to cut seconds per example.

## Migration Notes

No data migration. Developers need Chrome/Chromium locally for system specs. First `bundle install` after Gemfile change via `bin/setup`.

**Unblocking `main` if the seed flakes:** the gate is one workflow step plus one spec. Either drop the Chrome install step, or narrow the run to `bin/rspec spec/ --exclude-pattern "system/**"`, land the fix, and restore. Reverting the whole change is never the right response to a flake.

## References

- Prior tooling decision: `context/archive/2026-09-06-e2e-tooling-choice/analysis.md`
- Test plan: `context/foundation/test-plan.md`
- Interactive forms: `context/foundation/interactive-forms.md`
- Course skill (do not modify): `.cursor/skills/10x-e2e/`
- Auth cookie: `app/controllers/concerns/authentication.rb`
- Form UI: `app/views/game_sessions/_form.html.erb`, `_player_fields.html.erb`
- rspec-rails system specs: https://rspec.info/features/8-0/rspec-rails/system-specs/system-specs/
- Cuprite: https://github.com/rubycdp/cuprite
- Session cookie system sign-in pattern: Lewis Buckley / Rails SessionTestHelper discussions

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Wire Capybara + Cuprite + system auth

#### Automated

- [x] 1.1 Bundle resolves capybara and cuprite — 6474819
- [x] 1.2 System smoke or prelude green under bin/rspec with Cuprite — 6474819
- [x] 1.3 Request specs still pass — 6474819
- [x] 1.4 RuboCop clean on touched Ruby files — 6474819
- [x] 1.6 Smoke example asserts authenticated chrome, not just a green run — 6474819

#### Manual

- [x] 1.5 Headed cookie sign-in reaches authenticated page without login UI — 6474819

### Phase 2: Seed fidelity system spec

#### Automated

- [x] 2.1 Seed system spec green under bin/rspec spec/system — 4ef1c4b
- [x] 2.2 Deliberate-break confirms red then revert (not committed) — 4ef1c4b
- [x] 2.3 Non-system suite still green — 4ef1c4b
- [x] 2.6 Multi-player request example asserts participant set, not count — 4ef1c4b

#### Manual

- [x] 2.4 Seed assertion would fail if a submitted player were dropped — 4ef1c4b
- [x] 2.5 Optional headed Stimulus add-row validation — 4ef1c4b

### Phase 3: CI browser floor

#### Automated

- [x] 3.1 CI workflow includes browser availability for Cuprite — a780768
- [x] 3.2 CI=true bin/rspec spec/system green locally — a780768
- [x] 3.3 System specs are required (not allow_failure) — a780768
- [x] 3.5 Lefthook/zeitwerk unchanged and still pass on commit — a780768
- [x] 3.6 Failure artifact upload (tmp/screenshots + Ferrum stderr) wired with if: failure() — a780768

#### Manual

- [x] 3.4 GHA test job runs seed green after push — a780768

### Phase 4: Skill 10x-e2e-capybara

#### Automated

- [x] 4.1 Skill package with SKILL.md and five remapped references exists
- [x] 4.2 Course 10x-e2e tree untouched
- [x] 4.3 zeitwerk:check still passes

#### Manual

- [x] 4.4 Skill gate/seed path match Cuprite and Phase 2 file
- [x] 4.5 Repo pointer prefers 10x-e2e-capybara for this app

### Phase 5: Foundation sync

#### Automated

- [ ] 5.1 test-plan.md stack/cookbook/phase status updated
- [ ] 5.2 interactive-forms.md points at system-spec floor
- [ ] 5.3 spec/AGENTS.md documents system conventions
- [ ] 5.6 Root AGENTS.md states the local Chrome prerequisite

#### Manual

- [ ] 5.4 test-plan Phase 1/4 status is honest vs remaining request-oracle work
- [ ] 5.5 Docs do not present Playwright Node suite as project default
