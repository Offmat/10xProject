# Rails Interactive Forms Guide (F-04) — Plan Brief

> Full plan: `context/changes/rails-interactive-forms-guide/plan.md`
> Research: `context/changes/rails-interactive-forms-guide/research.md`

## What & Why

Ship durable, **stack-universal** guidance for interactive Rails forms (Stimulus / Hotwire / Turbo / params) so agents stop inventing fragile client-heavy patterns. F-04 unblocks reliable form work in this repo generally; S-03 is only one future consumer, not the subject of the guide.

## Starting Point

Research is complete (~980 lines) with principles, patterns, agent notes, a review checklist, and Cursor-rule candidates. The repo has almost no JS conventions today (scaffold Stimulus only) and a thin AGENTS / rules surface. Placement decisions: medium foundation playbook + one Apply Intelligently rule + one AGENTS pointer.

## Desired End State

Foundation playbook and short Cursor rule exist; root `AGENTS.md` points at the playbook; S-03 plan has a note about F-04 + two nested-form corrections; F-04 is marked done and archived. No app form code ships in this change.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Guide home | `context/foundation/interactive-forms.md` | Outlives the change; foundation is for cross-slice facts | Plan + Cursor/community practice |
| Research vs playbook | Shorten to medium (~250–350); archive full research | Agents need a re-readable guide; evidence stays in archive | Plan |
| Audience | Stack-universal, not S-03-centric | Guide must help any future interactive form on this stack | Plan (user) |
| Agent injection | Apply Intelligently `.mdc` (description, no globs) + AGENTS pointer | Forms span plans/ERB/JS; official docs forbid relying on globs+description hybrid | Research + Cursor docs |
| Rule body | Hard prohibitions + `@playbook` | Falsifiable, short, reference-not-copy | Research Deliverable 2 + Plan |
| S-03 plan | Note only (no Phase 3 rewrite) | Consumer gets corrections; F-04 does not own session-form implementation | Plan (user) |
| Archive | Final step of Phase 2 after human confirm | F-04 fully lands as foundation work | Plan (user) |

## Scope

**In scope:** Medium universal playbook; Apply Intelligently Cursor rule; root AGENTS pointer; note in `log-session-confirm-flow/plan.md`; roadmap/change status; `/10x-archive`.

**Out of scope:** Session form / Stimulus implementation; always-apply or glob twin rules; nested `app/javascript/AGENTS.md`; rewriting S-03 Phase 3 contracts; JS lint/Capybara; resolving unrelated research open questions (`played_at`, etc.).

## Architecture / Approach

```text
research.md (archive) ──redact──► foundation/interactive-forms.md
                                         ▲
                                         │ @-reference
                         .cursor/rules/hotwire-interactive-forms.mdc
                                         ▲
                         AGENTS.md one-line pointer
```

S-03 plan gets a short consumer note only.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Playbook and Cursor rule | Medium universal playbook + Apply Intelligently rule | Playbook drifts product-specific or rule grows into a guide |
| 2. Wire, note, close | AGENTS pointer, S-03 note, roadmap status, archive | Archiving before human skim; forgetting research pointer path after archive |

**Prerequisites:** `research.md` complete (done).
**Estimated effort:** ~1 session across 2 phases.

## Open Risks & Assumptions

- Agent-requested rules depend on a good `description`; if agents miss the rule in ERB/JS-only sessions, add a glob twin later (observed pain, not day-one).
- Playbook research pointer must use the archived path after `/10x-archive`.
- S-03 Phase 3 contracts remain stale until that change is updated; the note is the bridge.

## Success Criteria (Summary)

- Universal playbook + short rule are the living surfaces; research is archived evidence.
- Agents can discover guidance via AGENTS and/or the rule without loading a treatise every chat.
- F-04 is marked done and archived; S-03 implementers see the two nested-form corrections noted.
