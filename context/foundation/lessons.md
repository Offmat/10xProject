# Lessons Learned

> Append-only register of recurring rules and patterns. Re-read at start by /10x-frame, /10x-research, /10x-plan, /10x-plan-review, /10x-implement, /10x-impl-review.

## Never present findings before all sub-agents complete

- **Context**: Any skill that delegates to sub-agents
- **Problem**: The report was presented with only partial findings (4 of 11). The user had to notice the gap themselves and ask for a correction, otherwise the triage would have been incomplete.
- **Rule**: Never compile or present a report while sub-agents are still running. If sub-agents are taking too long, ask the user whether to wait longer or proceed without their findings.
- **Applies to**: all

## Cursor afterFileEdit is autofix, not agent-visible lint

- **Context**: Cursor hooks / local quality gates (`agent-hooks-triggers`)
- **Problem**: Treating `afterFileEdit` like Claude Code PostToolUse — expecting exit codes or stdout to steer the agent — fails. Cursor documents `afterFileEdit` for formatters; it has no `additional_context` schema. The edit has already landed; exit `2` does not undo it.
- **Rule**: Use `afterFileEdit` for safe autofix / post-process on disk. If the agent must *see* leftover offenses in chat, use `postToolUse` with `additional_context` (deferred follow-up from `agent-hooks-triggers`).
- **Applies to**: all
