# Agent hooks & Lefthook pre-commit — Plan Brief

> Full plan: `context/changes/agent-hooks-triggers/plan.md`
> Research: `context/changes/agent-hooks-triggers/research.md`

## What & Why

Add local quality automation from M3L3: Cursor `afterFileEdit` safe RuboCop on agent-edited Ruby, and Lefthook pre-commit (staged RuboCop + Zeitwerk), so style/autoload issues are caught before `bin/ci` / GHA without slowing the agent on heavy suites.

## Starting Point

No Cursor hooks or git hook manager today. RuboCop, security audits, Brakeman, and full RSpec already run via `bin/ci` and GitHub Actions. `.cursor/` is already committed for rules/skills.

## Desired End State

Agent Ruby edits get safe autocorrect on disk; commits run Lefthook (lint + Zeitwerk); clones learn install via `bin/setup` / README; foundation docs record that agent-visible leftover lint (`postToolUse`) is deferred on purpose.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Pre-commit tool | Lefthook | Best Rails fit: no Node, `{staged_files}`, brew/gem | Research |
| Per-edit check | RuboCop only (`-a`) | Safe autocorrect; avoid aggressive `-A` | Plan |
| Zeitwerk | Pre-commit only | Slow for every edit; good typecheck analog at commit | Plan |
| Lefthook install | Soft `bin/setup` + README | Matches existing optional setup; won’t break CI | Plan |
| Agent-visible lint | Defer `postToolUse`; foundation note | Autofix first; remember future `additional_context` | Plan |
| Heavy gates | Stay in `bin/ci` / GHA | Speed budget; research layer table | Research |

## Scope

**In scope:** `.cursor/hooks.json` + RuboCop script; `lefthook.yml`; `.gitignore` for `lefthook-local.yml`; soft Lefthook in `bin/setup`; README, AGENTS, test-plan §5, lessons, course-rule nudge.

**Out of scope:** `postToolUse` feedback; `-A`; per-edit Zeitwerk; RSpec/Brakeman/audits on hooks; Gemfile Lefthook gem; GHA changes; other harnesses’ hook files.

## Architecture / Approach

```
Agent edit → Cursor afterFileEdit → bin/rubocop -a (edited .rb)
git commit → Lefthook → bin/rubocop (staged) + zeitwerk:check
push/PR → existing bin/ci / GHA (unchanged)
```

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Cursor afterFileEdit RuboCop | Project hook + safe autofix script | Hook env PATH / jq missing |
| 2. Lefthook pre-commit | Staged lint + Zeitwerk; soft setup | CI setup must not hard-fail without Lefthook |
| 3. Docs & foundation reminder | README/AGENTS + deferred postToolUse note | Overlong AGENTS prose |

**Prerequisites:** Cursor Hooks enabled; optional `brew install lefthook` / `jq` for local verify.
**Estimated effort:** ~1 session across 3 phases.

## Open Risks & Assumptions

- Cursor `afterFileEdit` won’t inject lint into chat — deferred by design; foundation note must stay findable.
- Zeitwerk on every commit adds Rails boot cost — acceptable vs per-edit.
- Soft setup means some clones may commit without Lefthook until they install it.

## Success Criteria (Summary)

- Agent Ruby edit triggers safe RuboCop autofix (visible in Hooks channel / on disk).
- Lefthook blocks commits with staged RuboCop/Zeitwerk failures when installed.
- Docs + test-plan/lessons make deferred `postToolUse` agent feedback explicit for later.
