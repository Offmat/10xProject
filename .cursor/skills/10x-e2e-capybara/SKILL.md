---
name: 10x-e2e-capybara
description: Drive an approved plan's browser-level risks in the all-aBoard Rails app with Capybara, Cuprite, and RSpec — plan → generate → review → verify. Use for e2e, Capybara, system spec, browser risk, or executing browser-level phases on this app. Redirect non-browser work to /10x-tdd or /10x-implement.
---

# 10x E2E Capybara — Risk-Driven System Specs

> Derived from the course `/10x-e2e` skill (M3L4). This fork is the
> all-aBoard project skill for Capybara + Cuprite system specs; the course skill
> remains the unmodified Playwright version.

Drive one browser-level risk at a time through:

```text
PLAN     → select the risk, inspect the real Rails/Hotwire flow, map the outcome
GENERATE → write one RSpec system spec modeled on the live seed
REVIEW   → check the five agent E2E anti-patterns and re-prompt by name
VERIFY   → run green, then prove the spec turns red when the risk materializes
```

This is the browser-level sibling of `/10x-implement` and `/10x-tdd`. On the
plan path it reads the same `context/changes/<change-id>/plan.md`, mutates only
its canonical `## Progress` checkboxes, and follows the same phase-end commit
ritual. It does not build missing product features.

Invocation modes:

- Plan path: `/10x-e2e-capybara <change-id> [phase N]`
- Standalone path: `/10x-e2e-capybara <risk-id>` or no argument when the user
  clearly requests a one-off risk from `context/foundation/test-plan.md`
- Explicit plan path: `@context/changes/<change-id>/plan.md`

A standalone run performs the eligibility gate and one
PLAN→GENERATE→REVIEW→VERIFY cycle. It has no Progress mutation or commit ritual.

## Fixed project conventions

- Stack: Rails, RSpec, Capybara, Cuprite.
- Canonical seed:
  `spec/system/game_sessions/player_fidelity_spec.rb`.
- Runner for one system spec: `bin/rspec <path>`.
- Authentication: `sign_in_as` from
  `spec/support/authentication_helpers.rb`, which installs the signed session
  cookie through Cuprite. Never fill the login UI for setup.
- Specs require `rails_helper`, declare explicit `type: :system`, and live under
  `spec/system/`.
- Default placement: `spec/system/<feature>/<risk>_spec.rb`.
- Prefer one example per file when practical and one example per named risk.
- Do not require `playwright.config.*`, `*.spec.ts`, Playwright CLI, or
  Playwright MCP. Those are outside this fork's infrastructure gate.

## Scope and assumptions

- The feature already exists. If routes, views, controls, or behavior needed by
  the risk are missing, stop and redirect to `/10x-implement` (or `/10x-tdd`).
- Capybara/Cuprite system-spec infrastructure already exists. This skill checks
  it but does not install gems, create the driver, or wire CI.
- The quality levers are the live seed and these references. Read them; do not
  generate a replacement seed at a different path.
- Coverage count is not the goal. Add the smallest test that fails for the
  named browser-level risk.

## Setup — plan path only

Standalone runs skip plan resolution, change metadata, tasks, Progress, and
phase commits.

1. Resolve `/10x-e2e-capybara <change-id> [phase N]` to
   `context/changes/<change-id>/plan.md`. Accept an explicit active plan path.
   If it resolves under `context/archive/`, print:

```text
This change is archived. Open a new change with /10x-new instead.
```

Then stop.

If a plan-driven invocation gives no resolvable change, ask for a change id or
plan path and stop. Use `/10x-e2e-capybara` in every example and resume command.

2. Read the complete plan, including every phase, Changes Required block,
Success Criteria item, and the entire `## Progress` section. Progress is the
single execution-state authority; phase descriptions must not gain checkboxes.

3. Read `context/foundation/test-plan.md` and
`context/foundation/lessons.md` when present. The risk is the unit of work.

4. Confirm the Capybara/Cuprite floor:
   - `Gemfile` contains `capybara` and `cuprite` in the `:test` group.
   - `spec/support/capybara.rb` configures Cuprite for system specs.
   - `spec/support/authentication_helpers.rb` provides `sign_in_as`.
   - `spec/system/game_sessions/player_fidelity_spec.rb` exists.
   - A system spec can be invoked as `bin/rspec <path>`. Run the seed, or a
     narrower target system spec when the plan names one.

If any required floor is missing, stop with concrete evidence:

```text
This plan's browser phases need the all-aBoard Capybara/Cuprite system-spec
floor before I can drive them. Missing or failing:
- [Gemfile/support/seed/runner evidence]

Set up or repair that floor, then rerun:
→ /10x-e2e-capybara <change-id> phase [N]
```

Do not replace this with Playwright discovery.

5. Read all five references in this skill and the live seed. They are the
quality levers:
   - `references/seed-test-pattern.md`
   - `references/e2e-quality-rules.md`
   - `references/e2e-anti-patterns.md`
   - `references/e2e-prompt-template.md`
   - `references/browser-driven-generation.md`

6. Update `change.md` to `status: implementing` only when its current status is
`planned` or `plan_reviewed`; set `updated` to today's date.

7. Create one task per phase this skill will drive. Mark at most one current
phase in progress.

8. Start at the first unchecked row in `## Progress`, or the first unchecked row
under an explicitly requested phase.

### Clipboard convention

When handing off, copy the exact command with `pbcopy` on macOS, `clip.exe` on
Windows/WSL, or `xclip -selection clipboard` on Linux; fail silently if no
clipboard command exists. Display the command with `(✓ copied)`. Every E2E
resume command uses `/10x-e2e-capybara`.

## Eligibility gate — before every phase or standalone risk

Decide in this order:

1. **Browser-level fit:** does the risk cross real boundaries or exist only in
   rendered/interactive UI?
2. **Feature presence:** do the route, view, Hotwire behavior, and business path
   already exist and run?
3. **Test absence:** is there no passing system spec that already protects this
   risk?

All three must hold.

| Drive with `/10x-e2e-capybara` | Redirect to `/10x-tdd` or `/10x-implement` |
| --- | --- |
| Signed auth → route → controller/service → DB → rendered outcome | Pure model/service logic |
| Turbo/Stimulus behavior and nested form fidelity | One endpoint's status or params contract |
| Data survives real browser navigation or reload | Validator, parser, policy, or flag |
| Multi-step journey whose integration is the risk | Config, scaffolding, docs, infrastructure |
| Behavior visible only in the rendered page | Anything cheaper layers prove completely |

### Missing feature

If the feature is not built, stop:

```text
Phase [N]'s browser risk needs a running feature, but it is not built yet.

Missing evidence:
- [route/view/control/behavior]

Build it first:
→ /10x-implement <change-id> phase [N] (✓ copied)
```

### Existing test

Search `spec/system/` for the risk. If a passing spec already protects it, do
not regenerate it; mark the corresponding Progress row and continue. If the
spec exists but fails, diagnose the failure. Never weaken or silently rewrite
its business assertion as a generation step.

### Non-E2E redirect

For a clearly non-browser risk, explain why and ask:

1. Hand off to `/10x-tdd` (recommended when test-first fits).
2. Hand off to `/10x-implement`.
3. Force a system spec despite the cost.
4. Skip because it is already done.

On handoff, copy and display the selected command and stop:

```text
Phase [N] is not browser-level material — [reason].

→ /10x-tdd <change-id> phase [N] (✓ copied)

After that phase, resume with:
→ /10x-e2e-capybara <change-id> phase [N+1]
```

On skip, check the applicable Progress row without a SHA. For mixed risks, ask
whether to drive only the browser portion, redirect the entire phase, or force
all of it into a system spec.

## PLAN → GENERATE → REVIEW → VERIFY

Run one complete loop per browser-level risk.

### PLAN

1. State the contract: one named risk enters; one reviewed system spec that
fails when the risk happens exits.
2. Read the live seed and inspect the actual route, views, labels, form
partials, Stimulus controllers, service, and expected database outcome.
3. Prefer exploring through Capybara/Cuprite (`visit`, visible page text,
labels, and matchers) or by reading the views/Stimulus code. Playwright tools
are optional-only.
4. Map setup, `sign_in_as`, actions, Hotwire wait points, and the risk-tied
rendered/database assertion.
5. Keep Rails auth/session, routing, database, rendering, and Hotwire real.
Mock only expensive or non-deterministic external HTTP at the Rails server
boundary.
6. Use the prompt template only when a filled risk-specific prompt is helpful;
do not modify the reference template.

### GENERATE

1. Write a Ruby spec under `spec/system/<feature>/<risk>_spec.rb` with
`require 'rails_helper'` and explicit `type: :system`.
2. Model interaction style on
`spec/system/game_sessions/player_fidelity_spec.rb`:
   - `click_button`, `fill_in`, `select ... from:`, and `choose`;
   - waiting assertions such as `have_content`, `have_button`, `have_field`,
     `have_select`, and `have_css`;
   - no `sleep`;
   - unique records and values;
   - `sign_in_as`, never login UI.
3. Prefer labels and visible names. Scoped attribute finders inside `within`
are the sanctioned exception when repeated nested controls have no usable
label, as in the seed's player-row pattern.
4. Assert the business or DB outcome that fails if the risk materializes. A
success flash alone is not sufficient for persistence or fidelity risks.
5. Keep the example independently runnable and one example per file when
practical.

### REVIEW

Review every generated spec against the five exact anti-pattern names:

1. Hallucinated assertion
2. Brittle selector
3. Shared state between tests
4. Wait-for-time
5. No cleanup

For every violation, re-prompt by name with three parts: what is wrong, why it
does not protect the risk or creates false failures, and the replacement
pattern. Never use the vague instruction "fix this test."

### VERIFY

1. Run only the target spec:

```text
bin/rspec spec/system/<feature>/<risk>_spec.rb
```

2. Confirm it is green without pending/skipped examples.
3. Ask the control question: would it fail if the named risk occurred?
4. Perform a deliberate break of the protected production behavior or a safe
equivalent that proves the key assertion turns red. If it stays green, return
to GENERATE/REVIEW.
5. Revert the deliberate break immediately and rerun green. Never commit the
break.
6. On the plan path, flip only the completed automated Progress row from
`[ ]` to `[x]`; append no SHA until phase end.

A standalone run stops after reporting the green spec and deliberate-break
evidence.

## Phase completion — plan path only

Never commit while an in-scope spec is red, skipped, or while a deliberate
break remains.

Maintain a touched-file set for the phase: generated specs, risk-specific
prompt artifacts, `change.md` when changed, and the plan whose Progress was
updated. On the first phase, include existing modified/untracked files within
the active change folder. Reset the set after each phase.

1. Run every system spec added or changed in the phase and confirm green.
2. Present the manual gate and stop:

```text
Phase [N] Complete (Capybara E2E) — Ready for Manual Verification

Automated verification passed:
- [system specs]
- [deliberate-break behavior caught]

Please perform the plan's manual checks:
- [manual items]

Let me know when manual testing is complete so I can commit.
```

Do not check manual rows until the user confirms.

3. After confirmation, run `git status --porcelain`. If unrelated dirty paths
exist outside the touched set, ask whether to stage only the planned set
(recommended), stage all, or abort.
4. Stage touched files explicitly by path. Never use `git add .` or
`git add -A`.
5. If the cached diff is empty, keep completed rows SHA-less and continue.
6. Propose `test(<change-id>): <phase title> (p<N>)` and request approval. The
body names system specs and risks; add `Refs:` only for real issue links.
7. Commit once through normal hooks. Never bypass hooks, amend, or commit a
deliberate break.
8. Capture `git rev-parse --short HEAD` and append the SHA to every Progress row
flipped in this phase. Do not alter rows already carrying a SHA.
9. Set `change.md`'s `updated` date; keep `status: implementing` until all
Progress rows complete.

Then ask whether to continue, clear context, or run `/10x-impl-review`. For a
fresh context copy:

```text
→ /10x-e2e-capybara <change-id> phase [N+1] (✓ copied)
```

## Progress ritual

`plan.md`'s `## Progress` is the only execution state:

- The first unchecked row identifies the next work.
- Flip only rows whose criteria have actually passed.
- Mid-phase completed rows may be checked without a SHA.
- Append one phase commit SHA to rows completed in that phase.
- Never rename Progress titles.
- Never check manual rows without human confirmation.
- `/10x-e2e-capybara`, `/10x-tdd`, and `/10x-implement` may interleave because
  they follow the same ritual.

## After all phases

1. Scan for unchecked Progress rows. If any remain, list them by
Automated/Manual and ask whether to pause or proceed explicitly.
2. Set `change.md` to `status: implemented` and update its date. Do not archive
it.
3. Commit the final SHA write-back and status change as an approved epilogue:
`chore(<change-id>): close out plan (epilogue)`. Do not write the epilogue SHA
back into Progress.
4. Summarize phases driven, redirects, system specs, protected risks, and the
live seed. Offer `/10x-impl-review <change-id>`.

## Non-negotiable discipline

- Risk first, test second.
- Keep browser coverage small and cross-boundary.
- Wait for state with Capybara matchers; never `sleep`.
- Use `sign_in_as`; never use login UI as setup.
- Prefer labels and visible names; use scoped attribute finders only for the
  documented nested-field exception.
- Do not mock auth/session/DB/Hotwire boundaries carrying the risk.
- Do not accept decorative assertions, pending specs, or skipped examples.
- Do not silently rewrite assertions when business behavior changes.
- Confirm green → deliberate red → reverted green for every new risk spec.

## References

- `references/seed-test-pattern.md` — live player-fidelity seed conventions.
- `references/e2e-quality-rules.md` — Capybara/RSpec generation rules.
- `references/e2e-anti-patterns.md` — five anti-patterns and re-prompts.
- `references/e2e-prompt-template.md` — risk-specific system-spec prompt.
- `references/browser-driven-generation.md` — Cuprite exploration and
  PLAN→GENERATE→REVIEW→VERIFY mapping.
