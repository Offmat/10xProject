---
date: 2026-08-02T21:15:22+02:00
researcher: Mateusz Leśniak
git_commit: 13885bc9a26a24877f5508638a6d54b88072a377
branch: main
repository: 10xProject
topic: "Cursor afterFileEdit lint + Rails pre-commit (Lefthook); layer placement vs CI"
tags: [research, codebase, cursor-hooks, afterFileEdit, lefthook, rubocop, quality-gates, m3l3]
status: complete
last_updated: 2026-08-02
last_updated_by: Mateusz Leśniak
---

# Research: Cursor afterFileEdit lint + Rails pre-commit

**Date**: 2026-08-02T21:15:22+02:00
**Researcher**: Mateusz Leśniak
**Git Commit**: 13885bc9a26a24877f5508638a6d54b88072a377
**Branch**: main
**Repository**: 10xProject

## Research Question

How should this Rails 8.1 repo add M3L3-style local quality automation: Cursor `afterFileEdit` lint, a Rails-appropriate pre-commit gate, and a clear split of what belongs per-edit vs pre-commit vs CI?

## Summary

Nothing is wired today: no `.cursor/hooks.json`, no Lefthook/overcommit/husky, only sample files under `.git/hooks`. Quality already lives in sequential [`config/ci.rb`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/config/ci.rb) (`bin/ci`) and parallel GHA jobs in [`.github/workflows/ci.yml`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/.github/workflows/ci.yml).

**Recommended MVP for this change:**

1. **Per-edit (Cursor):** `afterFileEdit` → path-scoped `bin/rubocop` on the edited `*.rb` (autofix optional). Treat `bin/rails zeitwerk:check` as the course “typecheck” stand-in only if it stays fast; otherwise move it to pre-commit.
2. **Pre-commit:** **Lefthook** (best Rails fit among compared options) running RuboCop on staged Ruby files via `{staged_files}`.
3. **Leave in CI / `bin/ci`:** full RSpec, Brakeman, bundler-audit, importmap audit, Tailwind/setup — do not put these on `afterFileEdit`.

This satisfies the M3L3 lint (+ typecheck analog) exercise without fighting [`test-plan.md` §5](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/context/foundation/test-plan.md): the deferred “post-edit AI hook / multimodal visual review” gate is not the same as deterministic RuboCop.

**Cursor nuance vs Claude Code lesson:** `afterFileEdit` is documented for formatters/accounting and has **no** documented `additional_context` stdout schema. Agent-visible lint text is a `postToolUse` concern (`additional_context`). Exit code `2` blocks *pre*-actions; the edit has already landed on `afterFileEdit`.

## Detailed Findings

### Existing quality gates

Local pipeline ([`config/ci.rb`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/config/ci.rb#L3-L12)): Setup → RuboCop → bundler-audit → importmap audit → Brakeman → full RSpec. Setup pulls npm + Tailwind + DB via `bin/setup --skip-server`, so local `bin/ci` is heavier than GHA’s narrower test job.

GitHub Actions (four parallel jobs): Brakeman + bundler-audit; importmap audit; RuboCop (`bin/rubocop -f github`); npm ci + Tailwind + `bin/rspec spec/`. No job `timeout-minutes`. No RuboCop autocorrect in CI.

| Check | How | Speed tier |
|-------|-----|------------|
| RuboCop path | `bin/rubocop path.rb` | Per-edit friendly (~few seconds) |
| Full RuboCop | `bin/rubocop` | Pre-commit / CI |
| RSpec path | `bin/rspec spec/...` | Warm loop possible; not MVP per-edit |
| Full RSpec | `bin/rspec` | Pre-push / CI |
| Brakeman | `bin/brakeman ...` | CI / optional pre-push via `bin/ci` |
| bundler-audit / importmap | `bin/*` wrappers | Cheap but low value per-edit |
| Zeitwerk | `bin/rails zeitwerk:check` | Available; **not** in `bin/ci` or GHA today |
| Frontend lint | none | `package.json` is daisyUI only |

No Spring; `--only-failures` persistence is commented out in `spec/spec_helper.rb`. No Vitest-style `related` — closest is path convention (`app/.../foo.rb` → `spec/.../foo_spec.rb`).

Agents are already pointed at `bin/rubocop`, `bin/rspec`, `bin/ci` ([`AGENTS.md`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/AGENTS.md); [`spec/AGENTS.md`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/spec/AGENTS.md) says RuboCop on touched specs). Course rule still says not to configure hooks until M3L3 ([`.cursor/rules/10x-course.mdc`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/.cursor/rules/10x-course.mdc)).

### Cursor hook config (`afterFileEdit`)

**Present:** nothing — no project or user `hooks.json` / hooks scripts. m3l3 CLI package not applied (manifest last lesson `m3l2`).

**Shape** (project-level, from [Cursor hooks docs](https://cursor.com/docs/hooks) + create-hook skill):

```json
{
  "version": 1,
  "hooks": {
    "afterFileEdit": [
      {
        "command": ".cursor/hooks/rubocop-edited.sh",
        "timeout": 30
      }
    ]
  }
}
```

| Concern | Finding |
|---------|---------|
| Trigger | `afterFileEdit` (Cursor-native; Claude Code maps PostToolUse, not this event) |
| Stdin | `file_path` (absolute), `edits[]`; plus common session fields |
| Matcher | Optional JS regex on tool type (`Write`, `TabWrite`). Skill advice: get it working without matcher first |
| Output | No documented agent-injection fields for `afterFileEdit` (unlike `postToolUse` → `additional_context`) |
| Exit `0` | Success |
| Exit `2` | Block action (mostly meaningful for *before* hooks) |
| Other non-zero | Fail-open unless `failClosed: true` |
| Intended use | Formatters / post-process edited files |

**Practical RuboCop script pattern:**

1. Read stdin JSON → `.file_path`
2. Skip non-`*.rb` (and optionally non-Ruby roots)
3. Run `bin/rubocop -A --force-exclusion "$file"` (or safer `-a`) from repo root
4. Prefer side-effect autofix on disk; do not assume exit `2` stops the agent mid-loop
5. If the agent must *see* remaining offenses in chat: add a separate `postToolUse` hook (matcher `Write` / `StrReplace`) that emits `{ "additional_context": "..." }` with RuboCop stdout — that is the Cursor-native “agent reacts” path, closer to M3L3’s Claude Code exit-code story

Verify helpers (`jq`, `bin/rubocop`) are on `$PATH` in the hook environment; make scripts executable; debug via Cursor Hooks tab / Hooks output channel.

### Pre-commit: best option for this Rails repo

Compared: Lefthook, overcommit, Python `pre-commit`, husky+lint-staged, raw `.git/hooks`.

| Option | Fit here |
|--------|----------|
| **Lefthook** | **Primary pick** — stack-agnostic binary (brew/gem), `{staged_files}` + globs + `parallel`, Evil Martians / first-class RuboCop examples, commit `lefthook.yml`, skip with `LEFTHOOK=0`, no Node for hooks |
| overcommit | Ruby-native, maintained, but heavier install/signatures; unnecessary when CI already owns full gates |
| pre-commit | Adds a Python runtime this repo does not otherwise need |
| husky | Would hang hooks off a daisyUI-only `package.json` |
| Raw hooks | Unshared / easy to drift |

Official Lefthook patterns use `pre-commit` + `glob: "*.rb"` + `run: ... -- {staged_files}` (or modern `jobs:` form). Prefer project wrappers: `bin/rubocop --force-exclusion -- {staged_files}` so `vendor/bundle` via `bin/setup` stays authoritative.

Install once per clone: `brew install lefthook` (or gem) → `lefthook install`. Document in README or optional `bin/setup` step; do not auto-install in a way that surprises CI.

**Keep out of pre-commit:** full Brakeman, full RSpec, bundler-audit, importmap audit, Tailwind/`bin/setup`. Optional later: narrow related specs only if kept fast.

Historical note: deployment plan V5 treated `bin/ci` as the **local pre-push habit** ([`context/archive/2026-05-31-deployment-plan/deployment-plan.md`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/context/archive/2026-05-31-deployment-plan/deployment-plan.md)) — still a good home for the heavy suite; Lefthook pre-commit is the thin staged gate in front of that.

### Layer placement (per-edit vs pre-commit vs CI)

Reconcile M3L3 vs test-plan: §5 “post-edit AI hook / multimodal visual review — not planned” ([`test-plan.md` L102–108](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/context/foundation/test-plan.md#L102-L108)) defers **AI/visual** cost, not deterministic lint. Course layers are a menu; start with one per-edit lint + one commit gate.

| Check | Per-edit (`afterFileEdit`) | Pre-commit (Lefthook) | Pre-push | CI (`bin/ci` / GHA) |
|-------|----------------------------|------------------------|----------|---------------------|
| RuboCop | **Yes** — edited `.rb` only | **Yes** — staged `.rb` | Optional (covered by `bin/ci`) | **Yes** (already) |
| Zeitwerk | Yes if fast; else move up | **Yes** as typecheck analog | Optional | Consider adding later (not wired) |
| RSpec subset | No for MVP | Optional later | No | N/A as subset |
| Full RSpec | No | No | **Yes** (`bin/rspec` / `bin/ci`) | **Yes** |
| Brakeman | No | No | Via `bin/ci` | **Yes** |
| bundler-audit | No | Only if touching lockfile (optional) | Via `bin/ci` | **Yes** |
| importmap audit | No | Only if pins change (optional) | Via `bin/ci` | **Yes** |
| npm / Tailwind | No | No | Via `bin/ci` Setup | **Yes** |
| AI / visual post-edit | No (test-plan) | No | No | No |

Highest test-plan risks (#1–#4 session form / confirm / IDOR) still belong to **RSpec request/system** gates, not to per-edit RuboCop. Scoped related-spec hooks remain an optional later layer, not required for this change’s MVP.

## Code References

- [`config/ci.rb:3-12`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/config/ci.rb#L3-L12) — local CI step list
- [`bin/rubocop`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/bin/rubocop) — injects `.rubocop.yml`; passes file args through
- [`bin/rspec`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/bin/rspec) — thin rspec-core wrapper
- [`.rubocop.yml`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/.rubocop.yml) — Omakase + single quotes
- [`package.json`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/package.json) — daisyUI only; no husky
- [`context/foundation/test-plan.md:102-108`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/context/foundation/test-plan.md#L102-L108) — quality gates incl. deferred post-edit AI/visual
- [Cursor hooks docs](https://cursor.com/docs/hooks) — `afterFileEdit` input (`file_path`), exit codes, `postToolUse.additional_context`
- [Lefthook docs](https://github.com/evilmartians/lefthook) — `pre-commit` + `{staged_files}` RuboCop examples

## Architecture Insights

- **Two harnesses, one pattern:** trigger → match → check → signal. Cursor’s signal path for *agent-visible* lint is stronger on `postToolUse` than on `afterFileEdit`; autofix on `afterFileEdit` still closes the “agent wrote broken style” loop without waiting for CI.
- **Three local layers + CI already half-built:** CI and ad-hoc `bin/*` exist; missing pieces are deterministic per-edit and staged pre-commit.
- **Speed budget:** path RuboCop is the only check clearly justified on every agent edit; Zeitwerk is the typecheck stand-in; everything slower stays commit/push/CI (matches M3L3 heuristics).
- **Rails “related tests”** are convention/scripting, not a first-class runner flag — defer until a high-risk path needs it.

## Historical Context (from prior changes)

- [`context/archive/2026-05-31-deployment-plan/deployment-plan.md`](https://github.com/Offmat/10xProject/blob/13885bc9a26a24877f5508638a6d54b88072a377/context/archive/2026-05-31-deployment-plan/deployment-plan.md) — V5: `bin/ci` as local pre-push habit
- No prior change researched Lefthook / Cursor hooks; foundation/archive have no hook-manager mentions
- `context/changes/confirm-path-ownership/` — quality work via RSpec oracles, not hooks

## Related Research

- [`context/changes/confirm-path-ownership/research.md`](https://github.com/Offmat/10xProject/blob/main/context/changes/confirm-path-ownership/research.md) — request-spec quality for confirm/IDOR (complements, does not replace, lint hooks)

## Open Questions

1. Autofix aggressiveness on `afterFileEdit`: `-A` vs `-a` vs check-only (check-only needs `postToolUse` context injection for the agent to “see” failures).
2. Whether to add Zeitwerk to `bin/ci` / GHA as a permanent typecheck gate, or keep it local-only.
3. Whether `lefthook install` should be part of `bin/setup` or documented as a one-time developer step.
4. Optional follow-up: `postToolUse` + `additional_context` for true agent-visible lint feedback (beyond autofix).
5. Optional follow-up: scoped RSpec for top test-plan risks after edit — not in MVP.
