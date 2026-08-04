# Agent hooks & Lefthook pre-commit — Implementation Plan

## Overview

Add M3L3-style local quality layers: Cursor `afterFileEdit` safe RuboCop on edited Ruby files, and Lefthook pre-commit running staged RuboCop plus Zeitwerk. Ship Lefthook via the Gemfile and wire hooks from `bin/setup`, document for clones, and leave a foundation reminder that agent-visible lint via `postToolUse` / `additional_context` is deferred.

## Current State Analysis

- No `.cursor/hooks.json` or hook scripts; no Lefthook/overcommit/husky.
- Full gates already in [`config/ci.rb`](../../../../config/ci.rb) (`bin/ci`) and [`.github/workflows/ci.yml`](../../../../.github/workflows/ci.yml): RuboCop, bundler-audit, importmap audit, Brakeman, RSpec.
- `.cursor/` is tracked and not gitignored — project hooks should be committed like rules/skills.
- `bin/setup` already has soft-optional patterns (bundler-audit warn; skip `pg_isready` if missing).
- [`test-plan.md` §5](../../foundation/test-plan.md) marks “post-edit AI hook / multimodal visual review” as not planned; that does not block deterministic RuboCop. Cursor `afterFileEdit` has no documented agent `additional_context` — that path is `postToolUse`.

## Desired End State

- Agent edits to `*.rb` trigger safe RuboCop autocorrect (`-a`) via Cursor `afterFileEdit`.
- `git commit` runs Lefthook: RuboCop on staged Ruby + `bin/rails zeitwerk:check`.
- Fresh clones: `lefthook` comes from the Gemfile (`:development`); `bin/setup` runs `bundle exec lefthook install` after `bundle install`.
- Foundation docs record that agent-visible leftover lint feedback (`postToolUse`) is an intentional future item — not forgotten.

### Key Discoveries:

- Research: [`context/changes/agent-hooks-triggers/research.md`](research.md) — Lefthook preferred; layer table; Cursor autofix vs agent-context nuance.
- RuboCop wrapper passes path args: [`bin/rubocop`](../../../../bin/rubocop).
- Soft optional setup pattern: [`bin/setup:30-33`](../../../../bin/setup), [`bin/setup:41-43`](../../../../bin/setup).
- Prior tooling plan pattern (gitignore + setup + docs): `context/archive/2026-06-07-tailwind-daisyui-setup/plan.md`.

## What We're NOT Doing

- `postToolUse` / `additional_context` agent-visible lint (deferred; foundation note only).
- Aggressive RuboCop `-A` on edit (safe `-a` only).
- Zeitwerk on every `afterFileEdit` (pre-commit only).
- Full RSpec, Brakeman, bundler-audit, importmap audit, or Tailwind on per-edit or pre-commit.
- Related/scoped RSpec after edit.
- Hard-failing `bin/setup` when `lefthook install` fails (warn and continue).
- Changing GHA / `config/ci.rb` gate set (optional Zeitwerk-in-CI deferred).
- Configuring Claude Code / Codex / Copilot hook files.

## Implementation Approach

Three incremental phases: Cursor hook first (course-required per-edit lint), then Lefthook commit gate (lint + Zeitwerk), then docs/foundation reminder so deferred `postToolUse` work is discoverable. Prefer project wrappers (`bin/rubocop`, `bin/rails`) and fail-open hook scripts so a broken hook environment does not brick the agent.

## Critical Implementation Details

**Hook lifecycle:** `afterFileEdit` fires after the write lands — exit code `2` does not undo the edit. Scripts should autofix with `-a`, exit `0` on skip/non-Ruby, and avoid `failClosed: true`.

**Working directory:** Project hook commands run from the repo root; scripts must `cd` to the git root (or rely on Cursor’s cwd) before calling `bin/rubocop`.

**Lefthook + CI:** `bin/ci` runs `bin/setup --skip-server`. Lefthook is a Gemfile `:development` gem; setup runs `bundle exec lefthook install` and warns (does not exit) if that command fails.

**Adaptation (Phase 2):** Switched from brew/PATH soft-install to **Gemfile `lefthook`** so clones notice it in dependencies and get hooks via `bin/setup` after `bundle install`, with no separate brew step.

---

## Phase 1: Cursor afterFileEdit RuboCop

### Overview

Register a project Cursor hook that, after an agent file edit, runs safe RuboCop autocorrect on that file when it is Ruby.

### Changes Required:

#### 1. Hooks manifest

**File**: `.cursor/hooks.json`

**Intent**: Declare `version: 1` and an `afterFileEdit` command hook pointing at the project script, with a modest timeout and no `failClosed`.

**Contract**: Event key `afterFileEdit`; `command` relative to repo root (e.g. `.cursor/hooks/rubocop-edited.sh`); omit matcher on first version (tighten later if needed).

#### 2. RuboCop edit script

**File**: `.cursor/hooks/rubocop-edited.sh` (new; executable)

**Intent**: Parse stdin JSON for `file_path`, skip non-`.rb`, run safe autocorrect via the project wrapper, exit without blocking the agent.

**Contract**: Read absolute `file_path` from stdin (prefer `jq` if available; fall back to a tiny Ruby one-liner if `jq` is missing). Invoke `bin/rubocop -a --force-exclusion -- "$file_path"`. Skip silently for non-Ruby. Always exit `0` after attempting fix (or skip). Do not print agent JSON schemas that `afterFileEdit` does not support.

### Success Criteria:

#### Automated Verification:

- `.cursor/hooks.json` validates as JSON and references an executable script under `.cursor/hooks/`
- Script is executable (`test -x`)
- Dry-run: pipe sample stdin with a temp `.rb` path and confirm `bin/rubocop -a` is invoked (or skip for `.md`)
- `bin/rubocop` still passes on unchanged files: `bin/rubocop`

#### Manual Verification:

- In Cursor, edit a Ruby file via the agent and confirm the Hooks output channel / Hooks settings show `afterFileEdit` firing
- Introduce a safe-autocorrectable offense (e.g. double-quoted string where single quotes are enforced), save via agent edit, confirm file is fixed on disk

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 2: Lefthook pre-commit

### Overview

Add Lefthook as the git pre-commit manager: RuboCop on staged Ruby files and Zeitwerk check; install via Gemfile + `bin/setup`; ignore local overrides.

### Changes Required:

#### 1. Lefthook config

**File**: `lefthook.yml` (new)

**Intent**: Define a fast pre-commit gate scoped to staged Ruby, plus Zeitwerk as the typecheck analog.

**Contract**: Set `lefthook: bundle exec lefthook` so git hooks use the Gemfile binary. `pre-commit` with `parallel: true` where safe. RuboCop job: glob staged `*.rb` (and optionally `*.rake` / `Gemfile` if desired), run `bin/rubocop --force-exclusion -- {staged_files}` (check or safe fix — prefer check-only on commit so the developer re-stages intentionally; if autofix is used, re-stage must be explicit in the command). Zeitwerk job: `bin/rails zeitwerk:check` (no file glob). No RSpec/Brakeman/audits here.

#### 2. Gitignore local overrides

**File**: `.gitignore`

**Intent**: Keep personal Lefthook overrides out of git.

**Contract**: Add `lefthook-local.yml` (repo-root).

#### 3. Gemfile + setup install

**File**: `Gemfile`, `bin/setup`

**Intent**: Ship Lefthook as a visible `:development` dependency; wire git hooks from setup after `bundle install`.

**Contract**: `gem 'lefthook', require: false` in the `:development` group. After dependency install (near other soft checks), run `bundle exec lefthook install`; on failure `warn` and continue (never `exit 1` solely for Lefthook). Must remain safe under `bin/setup --skip-server` used by `bin/ci`.

### Success Criteria:

#### Automated Verification:

- `lefthook.yml` present; `bundle exec lefthook validate` succeeds
- `lefthook-local.yml` listed in `.gitignore`
- `lefthook` listed in Gemfile / Gemfile.lock; `bin/setup --skip-server` runs `bundle exec lefthook install` (warns on failure, does not abort)
- With hooks installed: staging a Ruby offense fails `git commit` (or Lefthook rubocop step); `bin/rails zeitwerk:check` is part of the pre-commit config

#### Manual Verification:

- After `bundle exec lefthook install` (or `bin/setup`), `git commit` on a staged dirty-style `.rb` is blocked by RuboCop
- Clean staged Ruby + passing Zeitwerk allows commit (or skip with `LEFTHOOK=0` documented for emergencies)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human before proceeding to the next phase.

---

## Phase 3: Docs & foundation reminder

### Overview

Document hooks for humans and agents; record deferred `postToolUse` agent-visible lint in foundation so it is not lost; thin pointers only in AGENTS.

### Changes Required:

#### 1. README developer setup

**File**: `README.md`

**Intent**: Tell clones how local quality layers work and how to install Lefthook.

**Contract**: Short subsection near “How to run the test suite” / system dependencies: Cursor project hooks (committed under `.cursor/`); Lefthook pre-commit (Gemfile `:development` gem; `bin/setup` / `bundle exec lefthook install`); note `LEFTHOOK=0` to skip; point to `bin/ci` for full gates.

#### 2. AGENTS.md thin pointers

**File**: `AGENTS.md`

**Intent**: Agents know per-edit and pre-commit exist without pasting long prose.

**Contract**: Under Build/test/development (and optionally Commits): one bullet each for Cursor `afterFileEdit` RuboCop (safe `-a`), Lefthook pre-commit (RuboCop + Zeitwerk), and that full suite stays `bin/ci`. No duplication of hook script internals.

#### 3. Test-plan quality gates

**File**: `context/foundation/test-plan.md`

**Intent**: Distinguish deterministic local hooks from deferred AI/visual and deferred agent-context injection.

**Contract**: Update §5 table / notes: deterministic RuboCop `afterFileEdit` + Lefthook pre-commit are local course/dev gates (not a substitute for CI). Keep “post-edit AI / multimodal visual” as not planned. Add an explicit deferred item: Cursor `postToolUse` + `additional_context` for agent-visible leftover RuboCop offenses (when autofix is insufficient). Refresh freshness ledger date if the section is edited.

#### 4. Lessons reminder

**File**: `context/foundation/lessons.md`

**Intent**: Capture the Cursor harness pitfall so future hook work does not assume Claude Code exit-code feedback on `afterFileEdit`.

**Contract**: Append one lesson: `afterFileEdit` is for format/autofix; agent-visible feedback needs `postToolUse` / `additional_context` — deferred in `agent-hooks-triggers`.

#### 5. Course rule nudge (if still blocking)

**File**: `.cursor/rules/10x-course.mdc`

**Intent**: Remove or soften any “do not configure hooks until Lesson 3” instruction now that this change implements them.

**Contract**: One-line update so agents are not told to refuse hook config after M3L3 is done.

### Success Criteria:

#### Automated Verification:

- Docs files exist and contain the agreed pointers (grep for `lefthook`, `afterFileEdit`, `postToolUse` / deferred note)
- `bin/rubocop` clean on any touched Ruby (setup only if Ruby changed)

#### Manual Verification:

- README instructions make sense to a fresh-clone reader
- `test-plan.md` §5 clearly separates: wired local lint hooks vs deferred AI/visual vs deferred `postToolUse` feedback

**Implementation Note**: After completing this phase, pause for human confirmation that docs match intent.

---

## Testing Strategy

### Unit Tests:

- None required — no application domain logic. Prefer script dry-runs and Lefthook validate.

### Integration Tests:

- None in RSpec. Verification is hook/Lefthook invocation + existing `bin/ci` still green.

### Manual Testing Steps:

1. Agent-edit a Ruby file with a safe style offense → file autocorrected.
2. Agent-edit a Markdown file → hook skips RuboCop.
3. Stage a RuboCop-failing `.rb` → commit blocked by Lefthook.
4. Run `bin/setup --skip-server` → Lefthook hooks sync via `bundle exec lefthook install`.
5. Skim foundation notes for deferred `postToolUse`.

## Performance Considerations

- Per-edit: path-scoped RuboCop only; keep timeout ~30s.
- Pre-commit: staged files + one Zeitwerk check; no full suite.
- Soft Lefthook in setup must not slow or break CI setup path.

## Migration Notes

- Existing clones: `bundle install` (pulls `lefthook`), then `bin/setup` or `bundle exec lefthook install`.
- No data migration. Gemfile gains `lefthook` in `:development`.
- Cursor may need Hooks enabled / reload after adding `hooks.json`.

## References

- Related research: `context/changes/agent-hooks-triggers/research.md`
- Cursor hooks: https://cursor.com/docs/hooks
- Lefthook: https://github.com/evilmartians/lefthook
- Prior tooling plan: `context/archive/2026-06-07-tailwind-daisyui-setup/plan.md`
- Quality gates: `context/foundation/test-plan.md` §5
- Local CI: `config/ci.rb`, `bin/ci`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Cursor afterFileEdit RuboCop

#### Automated

- [x] 1.1 hooks.json valid and references executable script — cbfdebe
- [x] 1.2 Script executable; dry-run skip vs Ruby path — cbfdebe
- [x] 1.3 bin/rubocop still clean on baseline — cbfdebe

#### Manual

- [x] 1.4 Cursor afterFileEdit fires in Hooks channel — cbfdebe
- [x] 1.5 Safe autocorrectable offense fixed on disk after agent edit — cbfdebe

### Phase 2: Lefthook pre-commit

#### Automated

- [x] 2.1 lefthook.yml present; validate when installed
- [x] 2.2 lefthook-local.yml in .gitignore
- [x] 2.3 bin/setup --skip-server soft-install behavior
- [x] 2.4 Pre-commit config includes RuboCop staged + Zeitwerk

#### Manual

- [x] 2.5 Dirty staged Ruby blocks commit
- [x] 2.6 Clean commit path (or LEFTHOOK=0) verified

### Phase 3: Docs & foundation reminder

#### Automated

- [ ] 3.1 README / AGENTS / test-plan / lessons contain agreed notes
- [ ] 3.2 Course rule no longer forbids hook config

#### Manual

- [ ] 3.3 Docs readable for fresh clone; deferred postToolUse note clear in test-plan
