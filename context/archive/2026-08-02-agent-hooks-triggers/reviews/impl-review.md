<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Agent hooks & Lefthook pre-commit

- **Plan**: context/changes/agent-hooks-triggers/plan.md
- **Scope**: Phases 1–3 of 3 (full plan)
- **Date**: 2026-08-04
- **Verdict**: NEEDS ATTENTION
- **Findings**: 0 critical 2 warnings 1 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | WARNING |
| Success Criteria | PASS |

## Findings

### F1 — Path containment in rubocop-edited.sh can be bypassed via `..` or symlink

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: .cursor/hooks/rubocop-edited.sh:21–29
- **Detail**: The `$ROOT/*` prefix check is string-based. A path like `$ROOT/../outside.rb` still matches the prefix and, if it exists, `bin/rubocop -a` can mutate a file outside the repo. An in-repo symlink whose target is outside the repo has the same effect. Stdin is normally trusted Cursor payload (not a public API), so this is defense-in-depth — not remote injection — but the script already claims to scope to the repo and the guard is incomplete. Shell injection is not an issue (`--` + quoted `"$FILE_PATH"`).
- **Fix A ⭐ Recommended**: Canonicalize with `realpath` (or equivalent) and require the resolved path to remain under `$ROOT`; reject paths that escape.
  - Strength: Closes both `..` and symlink escapes with one check; matches the script’s stated intent.
  - Tradeoff: Slightly more shell complexity; `realpath` availability differs by platform (macOS has it).
  - Confidence: HIGH — standard containment pattern; dry-run confirmed prefix bypass.
  - Blind spot: Whether Cursor ever supplies non-absolute or symlinked paths in practice.
- **Fix B**: Reject any `file_path` containing `..` and skip symlinks (`[[ ! -L ]]`).
  - Strength: Simpler than full realpath; blocks the common traversal case.
  - Tradeoff: Does not catch all symlink-to-outside cases if the path itself has no `..`.
  - Confidence: MEDIUM — incomplete vs Fix A.
  - Blind spot: Legitimate rare paths that include `..` components after normalization.
- **Decision**: FIXED via Fix A

### F2 — Course rule still teaches agent-visible hook feedback without Cursor afterFileEdit caveat

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: .cursor/rules/10x-course.mdc:14–15, 37–43, 65
- **Detail**: Phase 3 planned a one-line soften of “do not configure hooks until Lesson 3” — done (Lesson 3 now says hooks are in scope). But the universal loop still frames per-edit hooks as exit code → `additionalContext` → agent reacts, and the cross-tool table lists Cursor context injection as “yes”, with no Cursor-specific note that `afterFileEdit` has no `additional_context`. This conflicts with the lesson appended in `lessons.md` and the deferred `postToolUse` note in `test-plan.md`. Agents reading only the course rule can still misuse `afterFileEdit` for feedback.
- **Fix**: Add a short Cursor note near the exit-code / context-injection section: `afterFileEdit` is safe autofix only; agent-visible leftover lint needs `postToolUse` + `additional_context` (deferred).
- **Decision**: SKIPPED

### F3 — Relative file_path silently skips RuboCop

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: .cursor/hooks/rubocop-edited.sh:21–24
- **Detail**: Cursor docs specify absolute `file_path`. If a relative path ever arrives, the `$ROOT/*` check fails and the script exits 0 without running RuboCop — silent no-op. Unlikely in current Cursor behavior.
- **Fix**: If the path is not absolute, prepend `$ROOT/` (or resolve via `cd` + `realpath`) before the containment check.
- **Decision**: FIXED (covered by F1 realpath change)
