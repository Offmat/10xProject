<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Capybara E2E Prep

- **Plan**: `context/changes/capybara-e2e-prep/plan.md`
- **Mode**: Deep
- **Date**: 2026-09-06
- **Verdict**: REVISE → **SOUND after triage** (2026-09-08)
- **Findings**: 3 critical, 4 warnings, 3 observations — all 10 triaged, 9 fixed in the plan, 1 (F4) resolved as an accepted cost

## Verdicts

| Dimension | Verdict (at review) | After triage |
|-----------|---------------------|--------------|
| End-State Alignment | WARNING | PASS — F7 fixed (request oracle strengthened in Phase 2) |
| Lean Execution | WARNING | WARNING (accepted) — F4 keeps the full skill fork deliberately |
| Architectural Fitness | PASS | PASS |
| Blind Spots | FAIL | PASS — F1, F5, F8 fixed |
| Plan Completeness | FAIL | PASS — F2, F3, F6, F9, F10 fixed |

Both original failures were contract gaps in Phases 1–3, not problems with the approach. The strategy (Capybara + Cuprite, cookie sign-in, one risk-tied seed, CI gate) is sound.

## Triage outcome (2026-09-08)

| Finding | Decision |
|---------|----------|
| F1 Signed cookie generation | FIXED via Fix A — cookie-jar recipe pinned; new automated step 1.6 |
| F2 Locator policy vs DOM | FIXED via Fix A — row-scoped finders + choose-before-fill ordering |
| F3 Progress ↔ criteria drift | FIXED — 1:1 across all five phases (added 3.5, 3.6, 5.6, 2.6, 1.6) |
| F4 Full skill fork | FIXED via Fix B — full copy kept; rationale + accepted cost recorded in Phase 4 |
| F5 CI diagnostics / revert | FIXED — `if: failure()` artifact upload + unblock path in Migration Notes |
| F6 Explicit `type: :system` | FIXED — stated in Phase 1 contract and `spec/AGENTS.md` |
| F7 Weak request oracle | FIXED via Fix A — Phase 2 item 3 strengthens the multi-player example |
| F8 `js_errors` unset | FIXED — pinned `js_errors: false` for the floor |
| F9 Chrome prerequisite | FIXED — root `AGENTS.md` note (Phase 5 item 4); no `bin/setup` check |
| F10 Seed path undecided | FIXED — `spec/system/game_sessions/player_fidelity_spec.rb` |

## Grounding

10/10 paths ✓, 5/5 symbols ✓, brief↔plan ✓

Assumptions verified as **holding** (no findings needed):

- WebMock is `disable_net_connect!(allow_localhost: true)` (`spec/support/webmock.rb:3`) — Capybara's in-process Puma is not blocked.
- `allow_browser versions: :modern` (`app/controllers/application_controller.rb:4`) does **not** 406 headless Chrome: the headless UA parses via the vendored `useragent` gem as `browser="Safari", version=""`, so `BrowserBlocker#user_agent_version_reported?` is false and the blocker never fires.
- Params shape, `@friends` = accepted-only, creator persisted via `creator_score`, empty initial row set, and factory sufficiency (with the existing `:accepted` trait) all confirmed against the controller/service/factories.
- `bin/rspec` with no args picks up `spec/system/` — no `--pattern`/`--exclude-pattern` filters anywhere.

## Findings

### F1 — Signed cookie generation for system sign-in is unspecified

- **Severity**: ❌ CRITICAL
- **Impact**: 🔬 HIGH — architectural stakes; think carefully before deciding
- **Dimension**: Blind Spots
- **Location**: Critical Implementation Details → "System `sign_in_as`"; Phase 1 item 3
- **Detail**: `plan-brief.md` names "Cookie sign-in mismatch with signed jar" as Phase 1's key risk, but the plan never resolves it. The contract says only: set `cookies.signed[:session_id]` "equivalent via Cuprite `set_cookie`". There is no `cookies.signed` jar in a system spec (that's an `ActionDispatch::IntegrationTest` facility), so the implementer must hand-generate the signed value, and three things must line up exactly with production: the `"signed cookie"` salt derived from `secret_key_base`, the JSON serializer (`config.load_defaults 8.1` → `cookies_serializer = :json`, railties `configuration.rb:231`), and the purpose metadata Rails embeds since 6.0 (`"cookie.session_id"`). Get any of them wrong and there is no error — the browser is simply anonymous, `require_authentication` redirects to `/session/new`, and the failure presents as a mystifying locator miss inside the seed. Phase 1's automated criteria can't catch it either: 1.2 only asserts a spec is green, and only manual step 1.5 checks that sign-in actually worked.
- **Fix A ⭐ Recommended**: Build the value through a real cookie jar — `ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})`, assign `jar.signed[:session_id] = session.id`, then hand `jar[:session_id]` to `page.driver.set_cookie`.
  - Strength: Salt, serializer, and purpose metadata come from the same code path production uses, so it can't drift when a future `load_defaults` bump changes the serializer.
  - Tradeoff: Depends on a semi-private ActionDispatch API.
  - Confidence: HIGH — serializer and metadata defaults verified in the vendored railties/actionpack 8.1.3.
  - Blind spot: Cuprite's `set_cookie` needs an explicit domain/path; not yet verified against `Capybara.server_host`.
- **Fix B**: Test-only sign-in route — a `Rails.env.test?`-guarded route the helper `visit`s, letting production `start_new_session_for` set the cookie itself.
  - Strength: Zero crypto duplication; exercises the real cookie writer.
  - Tradeoff: Test-only surface in `config/routes.rb` — Brakeman may flag it, and the route exists in the production file.
  - Confidence: MEDIUM — clean, but adds prod-adjacent surface for a test need.
  - Blind spot: Interaction with rate limiting on session create not checked.
- **Either way**: promote "browser is actually authenticated" to an automated Phase 1 criterion (assert authenticated nav/chrome on a protected page) rather than leaving it to manual step 1.5.
- **Decision**: FIXED via Fix A

### F2 — Phase 2's locator policy is not executable against the real form DOM

- **Severity**: ❌ CRITICAL
- **Impact**: 🔬 HIGH — architectural stakes; think carefully before deciding
- **Dimension**: Plan Completeness
- **Location**: Implementation Approach; Phase 2 item 1 contract
- **Detail**: The plan mandates "Prefer label/button/text finders over CSS" and lists `fill_in` / `select` / `choose`. Against `app/views/game_sessions/_player_fields.html.erb` that policy breaks in four places: (a) **Score** — the `<label>` has no `for`, doesn't wrap the input, and the input has no `id`, so `fill_in 'Score'` cannot resolve it at all; (b) **friend select** — no id, no label, no placeholder, reachable only by its name `game_session[players][<index>][user_id]`; (c) **guest name** — reachable only by placeholder `"Guest name"`; (d) **Friend/Guest radios** do wrap their inputs (so `choose` works) but repeat per row, so every one is ambiguous without `within`. Worse, indices aren't predictable: `@player_rows = []` renders zero rows, and `nested_form_controller.js` seeds `#index = Date.now()`, so added rows get timestamp indices — any hardcoded `[0]` name locator fails. There's also an ordering constraint the plan doesn't mention: the guest fieldset ships `disabled` (rows default to type `'friend'`), so the spec must `choose 'Guest'` inside the row to fire `player-fields#toggle` *before* the guest name field is fillable. As written, an implementer following the stated policy hits ambiguous-match and element-not-found errors on the first run.
- **Fix A ⭐ Recommended**: Specify row-scoped finders in the contract — write the seed against `within(all('[data-nested-form-row]').last) { ... }` after each add-row, using name-suffix finders (e.g. `find('[name$="[score]"]')`) inside the scope, and note the choose-Guest-before-fill ordering.
  - Strength: Touches no production markup; row scoping is index-agnostic, so it survives the `Date.now()` indices and future row reordering.
  - Tradeoff: Concedes the "no CSS locators" rule for two fields, so the new skill's quality rules must describe scoped-attribute finders as the sanctioned exception rather than banning CSS outright.
  - Confidence: HIGH — derived directly from the partial and the Stimulus source.
  - Blind spot: Whether Cuprite reports the toggled-enabled fieldset as interactable without an explicit wait is unverified.
- **Fix B**: Add accessible ids/labels to `_player_fields.html.erb` — indexed `id` per input with matching label `for` (and an `aria-label` on the friend select), then use pure label finders.
  - Strength: Fixes a genuine accessibility defect (those score labels are unusable for screen readers today) and keeps the locator policy intact for the skill to teach.
  - Tradeoff: Modifies production markup to serve a test, brushing against Phase 2's "do not change production models for the test"; label text still repeats per row, so `within` is needed regardless.
  - Confidence: MEDIUM — small change, but it widens Phase 2's blast radius into views covered by existing request specs.
  - Blind spot: daisyUI label styling may assume the current nesting.
- **Decision**: FIXED via Fix A

### F3 — Progress section doesn't match Success Criteria in Phases 3, 4, and 5

- **Severity**: ❌ CRITICAL
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: `## Progress` (Phases 3–5)
- **Detail**: `progress-format.md` makes Progress a mechanical contract, and step titles become immutable once the plan is reviewed — so this must be fixed before `/10x-implement` parses it. **Phase 3**: criterion "CI workflow YAML validates structurally" has no matching row (3.1 reads "includes browser availability"), and criterion "Lefthook/zeitwerk unchanged and still pass on commit" has no row at all, while 3.3 ("System specs are required, not allow_failure") has no corresponding criterion. **Phase 4**: manual criterion "Confirm course 10x-e2e folder untouched" has no row (it duplicates automated 4.2), while row 4.5 ("Repo pointer prefers 10x-e2e-capybara") has no criterion. **Phase 5**: 2 automated criteria vs 3 automated rows; row 5.5 restates the automated "no Playwright as default" criterion as a manual check. Phases 1 and 2 are clean.
- **Fix**: Reconcile Progress 1:1 with each phase's Success Criteria bullets — add rows for the unmatched criteria, add criteria for rows worth keeping (3.3 and 4.5 are both legitimate checks), and drop the duplicated ones.
- **Decision**: FIXED

### F4 — Full 51 KB fork of the course skill for a syntax remap

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Lean Execution
- **Location**: Phase 4 item 1
- **Detail**: `.cursor/skills/10x-e2e/SKILL.md` is 31 KB and its five references total 20 KB. Phase 4 copies and remaps all of it — the largest single chunk of work in the change — yet it contributes nothing to the tested floor that Phases 1–3 deliver. Most of that text (the PLAN→GENERATE→REVIEW→VERIFY workflow, the eligibility gate, the Progress ritual, the five anti-pattern names) is tool-agnostic and would be duplicated verbatim, creating a 51 KB drift surface against an upstream artifact `10x-cli` can refresh.
- **Fix A ⭐ Recommended**: Thin fork that delegates the workflow — new `SKILL.md` owns the eligibility gate, Cuprite/`spec/system` discovery, and a Playwright→Capybara syntax mapping table, delegating workflow and anti-pattern discipline by reference to `.cursor/skills/10x-e2e/SKILL.md`. Fork only the references whose content is genuinely Playwright-specific (`seed-test-pattern.md`, `e2e-quality-rules.md`).
  - Strength: Cuts Phase 4 to roughly a third; workflow prose can't drift because there's only one copy.
  - Tradeoff: The project skill is no longer self-contained — it reads the course skill, so a future lesson refresh could shift the workflow underneath it.
  - Confidence: MEDIUM — depends on how much of the 31 KB is truly Playwright-coupled; worth a skim before committing.
  - Blind spot: Whether Cursor skill loading follows cross-skill references reliably in practice.
- **Fix B**: Full copy as planned.
  - Strength: Immune to upstream lesson refreshes; one file to read.
  - Tradeoff: 51 KB of duplicated guidance; the anti-pattern and prompt templates will silently diverge from the course version.
  - Confidence: HIGH — it plainly works, it's just expensive.
  - Blind spot: None significant.
- **Decision**: FIXED via Fix B (full copy kept deliberately; rationale recorded in Phase 4)

### F5 — CI gate has no failure diagnostics and no revert path

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Blind Spots
- **Location**: Phase 3; Migration Notes
- **Detail**: Phase 3 makes system specs a hard gate ("Do not mark system specs `allow_failure`") on the same `bin/rspec spec/` invocation that runs every other spec, so one Cuprite hiccup blocks all merges including doc-only PRs. The plan's own Performance Considerations concede Cuprite "exposes Hotwire race conditions", and no phase covers what happens when it does: no screenshot/artifact upload (Capybara writes `tmp/screenshots` on failure — invisible in CI without an upload step), no Ferrum log capture, and no documented way to unblock `main`. A red seed with no artifact is close to undebuggable from a GHA log alone.
- **Fix**: Add a Phase 3 step uploading `tmp/screenshots` (and Ferrum stderr) as a GHA artifact with `if: failure()`, and record a one-line unblock path in Migration Notes (drop the Chrome step, or `--exclude-pattern "system/**"`) so a flake doesn't force a revert of the whole change.
- **Decision**: FIXED

### F6 — spec type inference is disabled; system specs need explicit metadata

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 1 item 2 contract
- **Detail**: `config.infer_spec_type_from_file_location!` is commented out (`spec/rails_helper.rb:64`) and `.rspec` carries only `--require spec_helper`. So a file under `spec/system/` gets neither `rails_helper` nor `type: :system` for free — `before(type: :system)` never fires, `driven_by` never runs, and `visit` is undefined. Phase 2's contract does say `type: :system`, but Phase 1's driver contract doesn't state the prerequisite, and the Phase 1 smoke spec (step 1.2) is where it will bite first.
- **Fix**: State in the Phase 1 contract that every system spec must `require 'rails_helper'` and declare `type: :system` explicitly (inference stays off), and carry the same note into `spec/AGENTS.md`.
- **Decision**: FIXED

### F7 — Risk #1 stays weakly guarded at the request layer after this change

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: End-State Alignment
- **Location**: What We're NOT Doing; Phase 5 item 1
- **Detail**: `test-plan.md` §3 Phase 1 covers Risks #1 and #2 with "system (+ tighten request oracles)", and §2 names the thing to challenge for #1 as "HTTP success ⇒ all players saved". The multi-player request spec today asserts exactly what the risk map lists as the anti-pattern: `expect(game_session.game_session_participants.count).to eq(3)` (`spec/requests/game_sessions_spec.rb:70-88`) — no identities, scores, or statuses. The only strong participant oracle lives in `spec/services/unit/game_sessions/create_spec.rb:45-71`, which calls the service directly and never touches params. So after this change the browser half is covered by one seed, and the HTTP half still can't tell 3 correct participants from 3 wrong ones.
- **Fix A ⭐ Recommended**: Strengthen the existing request oracle in Phase 2 — add a step replacing the `count` assertion with a participant-set assertion (identity, score, status per row), mirroring the service spec.
  - Strength: ~10 lines in a spec the change is already reading; closes Risk #1 at both layers so test-plan Phase 1 can close honestly.
  - Tradeoff: Slight scope growth against the explicit "not doing" item.
  - Confidence: HIGH — the assertion pattern already exists in `create_spec.rb:45-71` and can be lifted nearly verbatim.
  - Blind spot: Other request specs may assert counts the same way; only the multi-player example was checked.
- **Fix B**: Keep the deferral, make the docs unambiguous — in Phase 5, mark §3 Phase 1 "partial — system half only" and add an explicit follow-up row for the request-oracle work.
  - Strength: Honors the stated scope; foundation stays truthful.
  - Tradeoff: Leaves a known weak oracle on the highest-ranked risk with only a doc note guarding it.
  - Confidence: HIGH — purely editorial.
  - Blind spot: None significant.
- **Decision**: FIXED via Fix A

### F8 — `js_errors` listed without a value

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Blind Spots
- **Location**: Phase 1 item 2 contract
- **Detail**: The contract names `js_errors` but not its setting. With `js_errors: true` Cuprite raises on any page JS error, so unrelated Turbo/importmap console noise becomes a seed failure — and it muddies step 2.2, where a deliberate break must produce a red for the *expected* reason.
- **Fix**: Set `js_errors: false` for the floor; revisit once a clean baseline run confirms the page is error-free.
- **Decision**: FIXED

### F9 — Chrome prerequisite isn't documented where developers look

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Migration Notes; Phase 3 item 2; Phase 5
- **Detail**: Migration Notes state developers need Chrome locally, but no phase puts that anywhere a developer reads: root `AGENTS.md` owns "Build, test, and development", and Phase 3 item 2 only touches it "if a command note is required". `bin/setup` already warns on missing Postgres via `pg_isready` — a missing browser deserves the same treatment, since without it `bin/rspec` fails for reasons unrelated to the developer's change.
- **Fix**: Add a one-line Chrome prerequisite to root `AGENTS.md` in Phase 5, or a `pg_isready`-style presence warning in `bin/setup`.
- **Decision**: FIXED (root `AGENTS.md` note; `bin/setup` check not adopted)

### F10 — Seed spec path left undecided but referenced by three artifacts

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 2 item 1
- **Detail**: Phase 2 offers `spec/system/game_sessions/player_fidelity_spec.rb` "(or `spec/system/seed_player_fidelity_spec.rb`)", while Phase 4 must point the new skill at "the seed path", Phase 5 must make docs "mention seed path", and Progress step 4.4 verifies they match. Three downstream artifacts depend on a path the plan leaves as a coin flip.
- **Fix**: Commit to `spec/system/game_sessions/player_fidelity_spec.rb` — it mirrors the existing `spec/requests/game_sessions_spec.rb` layout.
- **Decision**: FIXED
