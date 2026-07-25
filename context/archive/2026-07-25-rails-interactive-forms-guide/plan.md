# Rails Interactive Forms Guide (F-04) Implementation Plan

## Overview

Land F-04 as durable, **stack-universal** guidance for interactive Rails forms (Hotwire / Stimulus / Turbo / params), so agents and humans implement this class of UI consistently in any future slice — not as a session-form playbook. Research is complete; this plan distills it into a medium foundation playbook, one Apply Intelligently Cursor rule, thin discovery wiring, a consumer note on the in-flight S-03 plan, then archive.

## Current State Analysis

- [`research.md`](research.md) is a complete evidence-backed guide (~980 lines) with principles, patterns, agent notes, a review checklist, and Cursor-rule candidates (Deliverables 1–3). It remains the evidence archive after F-04 ships.
- Roadmap F-04 expects: researched playbook + short agent-facing rules; playbook stays available for deeper lookup ([`context/foundation/roadmap.md`](../../foundation/roadmap.md) F-04 section).
- Repo agent surface is immature: root [`AGENTS.md`](../../../AGENTS.md) is an index (three Architecture pointers; no forms entry); [`app/AGENTS.md`](../../../app/AGENTS.md) has Auth / Services / Views only; `.cursor/rules/` has `web-search.mdc` (`alwaysApply`) and course `10x-course.mdc`; no `docs/` or `app/javascript/AGENTS.md`.
- Cursor rules support four activation modes; for cross-cutting form work (plans + ERB + JS + Ruby), **Apply Intelligently** (`description`, no `globs`) is the right first rule. Official docs: reference files instead of pasting guides; start simple.
- [`log-session-confirm-flow/plan.md`](../log-session-confirm-flow/plan.md) Phase 3 still specifies `Date.now()` alone and a single `nested-form` controller for row internals — research corrected both. F-04 does **not** rewrite that plan’s form section; it only adds a note pointing at the corrections and the new playbook.

### Key Discoveries:

- Stimulus is glue; interactive forms are mostly a server-rendering problem (research Summary).
- Hard agent failure modes are falsifiable and rule-shaped (Deliverable 2); judgement calls must stay out of rules (Deliverable 3).
- Nested `AGENTS.md` / glob twin rules are deferred until observed pain — do not invent a mature agent stack in this change.

## Desired End State

- `context/foundation/interactive-forms.md` exists as a medium (~250–350 line), **universal** playbook (principles, ladder, state, condensed patterns, agent pitfalls, checklist, “not a rule” list). No S-03 ERB/JS centerpiece; optional one-line pointer to archived research for evidence / project-specific application.
- `.cursor/rules/hotwire-interactive-forms.mdc` is Apply Intelligently: hard prohibitions from Deliverable 2 + `@context/foundation/interactive-forms.md`.
- Root `AGENTS.md` Architecture pointers include the playbook.
- `log-session-confirm-flow/plan.md` has a short note that F-04 landed and lists the two nested-form corrections (without rewriting Phase 3 contracts).
- Roadmap F-04 marked done; change archived via `/10x-archive`.

### How to verify

- Playbook and rule files exist at the paths above; rule frontmatter has `alwaysApply: false`, a concrete `description`, and **no** `globs`.
- Root `AGENTS.md` links `@context/foundation/interactive-forms.md`.
- S-03 plan note is present and does not replace the Phase 3 form contracts.
- Change folder lives under `context/archive/` after Phase 2 archive step.

## What We're NOT Doing

- Implementing the S-03 session form, Stimulus controllers, or any app runtime code.
- Promoting research wholesale into foundation (no clone tables, external citation dumps, or §14 worked example as the playbook body).
- Always-apply forms rules; glob-scoped twin rules; nested `app/javascript/AGENTS.md`.
- Duplicating rule text into `AGENTS.md` or pasting the playbook into the `.mdc`.
- Rewriting `log-session-confirm-flow` Phase 3 form contracts (note only).
- Deciding Capybara / `disabled:hidden` / `played_at` / other research open questions that belong to product slices.
- Adding JS lint, jsdom, or Capybara as part of F-04.

## Implementation Approach

Two phases: (1) produce the two load-bearing artifacts from research by redaction and distillation; (2) wire discovery, leave a consumer note, update status, archive. Keep injection lean: playbook for depth, one agent-requested rule for constraints, one AGENTS pointer for discoverability.

## Phase 1: Playbook and Cursor rule

### Overview

Write the medium universal foundation playbook and the Apply Intelligently Cursor rule that points at it.

### Changes Required:

#### 1. Foundation playbook

**File**: `context/foundation/interactive-forms.md`

**Intent**: Living, edit-in-place playbook for interactive Rails forms with Stimulus/Hotwire — usable for any future form work in this stack.

**Contract**: Target ~250–350 lines. Required sections (names may vary slightly): purpose; 10 principles (from research Summary); escalation ladder; state-ownership table (condensed); controller + HTML essentials; condensed pattern catalogue (radio/conditional/`disabled`, dynamic nested rows, multi-instance, Turbo re-render survival — universal, not product-specific); notes for AI coding agents; code-review checklist (Deliverable 1); short “should NOT become rules” list (Deliverable 3); pointer to archived `context/archive/.../rails-interactive-forms-guide/research.md` (or the in-flight path until archive) for evidence and optional project application. Explicitly **omit** an S-03 ERB/JS worked example as a centerpiece. Prefer single-quoted strings only if any code samples are included; keep samples short.

#### 2. Cursor rule

**File**: `.cursor/rules/hotwire-interactive-forms.mdc`

**Intent**: Short, falsifiable agent constraints that load when the agent judges the task is about interactive Rails forms.

**Contract**: YAML frontmatter with `alwaysApply: false`, a `description` that triggers on building/changing/reviewing interactive Rails forms with Stimulus/Hotwire (nested/dynamic fields, conditional branches, params shape, Turbo form re-renders), and **no `globs`**. Body: hard prohibitions from research Deliverable 2 (items 1–10), optionally a minimal subset of required practices only if needed for clarity — default is prohibitions only. End with an instruction to read `@context/foundation/interactive-forms.md` before inventing a new pattern. Do not paste the playbook or checklist into the rule.

### Success Criteria:

#### Automated Verification:

- `context/foundation/interactive-forms.md` exists and is roughly 250–350 lines (manual count OK; no CI gate).
- `.cursor/rules/hotwire-interactive-forms.mdc` exists with `alwaysApply: false`, non-empty `description`, and no `globs` key.
- Rule body contains hard prohibitions and an `@context/foundation/interactive-forms.md` reference.
- Playbook has no dedicated S-03 session-form ERB/JS centerpiece section.

#### Manual Verification:

- Skim playbook: a reader unfamiliar with S-03 can still apply it to a different interactive form.
- In Cursor Customize → Rules, the new rule appears as Apply Intelligently (or equivalent) with a sensible description.

**Implementation Note**: After Phase 1 automated checks pass, pause for a quick human skim of playbook + rule before Phase 2.

---

## Phase 2: Wire discovery, consumer note, close F-04

### Overview

Make the playbook discoverable, leave a note for the S-03 consumer plan, update roadmap/change status, and archive the change after human confirmation.

### Changes Required:

#### 1. Root AGENTS pointer

**File**: `AGENTS.md`

**Intent**: Index the playbook the same way other foundation docs are indexed.

**Contract**: Add one bullet pointing at `@context/foundation/interactive-forms.md` (interactive Rails forms / Stimulus / Hotwire) under a `## Guides` section in root `AGENTS.md` — separate from `## Architecture pointers` since the playbook is a how-to guide, not an architecture reference. Do not paste rules or playbook prose.

#### 2. S-03 consumer note

**File**: `context/changes/log-session-confirm-flow/plan.md`

**Intent**: Alert implementers that F-04 landed and that two nested-form assumptions in Phase 3 need updating when that work resumes — without rewriting the Phase 3 contracts in this change.

**Contract**: Add a short note (near the top Notes / Overview, or immediately above Phase 3 form items) stating: (1) F-04 playbook is at `@context/foundation/interactive-forms.md`; (2) when implementing the session form, prefer the playbook + rule over the Phase 3 nested-form sketch where they conflict; (3) two known corrections from F-04 research — row indices must be **unique and numeric** (monotonic counter seeded from `Date.now()`, not bare `Date.now()` alone), and the per-row friend/guest toggle needs its **own Stimulus controller identifier** (not the same identifier as the container). Do not rewrite `_form` / `_player_fields` / `nested_form_controller` Contract blocks in this change.

#### 3. Change and roadmap status

**Files**: `context/changes/rails-interactive-forms-guide/change.md`, `context/foundation/roadmap.md`

**Intent**: Record that F-04 content has landed before archive.

**Contract**: Update `change.md` (`updated`, status toward implemented / ready to archive per project convention; note playbook + rule paths). Mark F-04 as done in `roadmap.md` (slice status and summary table as applicable).

#### 4. Archive

**Intent**: Move the completed change out of `context/changes/` so foundation docs remain the living surface.

**Contract**: After human confirmation that Phase 1–2 content is good, run `/10x-archive rails-interactive-forms-guide` (or equivalent skill invocation). Do not hand-edit under `context/archive/`.

### Success Criteria:

#### Automated Verification:

- Root `AGENTS.md` contains `@context/foundation/interactive-forms.md`.
- `log-session-confirm-flow/plan.md` contains a note mentioning F-04 / the playbook path and both corrections (numeric indices; separate row controller identifier).
- `roadmap.md` F-04 status reflects done.
- After archive: change folder is under `context/archive/` and absent from `context/changes/rails-interactive-forms-guide/`.

#### Manual Verification:

- Opening a new Agent chat about “dynamic nested form with Stimulus” should be able to discover the playbook via AGENTS and/or the rule description (smoke-check once).
- Confirm archive completed via `/10x-archive` before treating F-04 as closed.

**Implementation Note**: Do not run archive until the human confirms playbook + rule + note look right.

---

## Testing Strategy

### Unit Tests:

- None — documentation / agent-config change only.

### Integration Tests:

- None.

### Manual Testing Steps:

1. Open the playbook and confirm it reads as stack-universal (no product-feature centerpiece).
2. Confirm the Cursor rule shows as agent-requested / Apply Intelligently in the Rules UI.
3. Grep or open `AGENTS.md` and the S-03 plan note.
4. After archive, confirm the change path under `context/archive/`.

## Performance Considerations

Keep the Cursor rule short (prohibitions + `@` reference) so agent-requested loads stay cheap. Playbook is loaded only when referenced or opened — not via `alwaysApply`.

## Migration Notes

No data or runtime migration. After archive, deep links to `context/changes/rails-interactive-forms-guide/research.md` should use the archived path; the playbook’s research pointer should be updated in Phase 2 if written with the pre-archive path in Phase 1.

## References

- Related research: `context/changes/rails-interactive-forms-guide/research.md`
- Roadmap: `context/foundation/roadmap.md` (F-04)
- Foundation conventions: `context/foundation/README.md`
- Cursor rules docs: https://cursor.com/docs/rules.md
- Consumer plan (note only): `context/changes/log-session-confirm-flow/plan.md` (Phase 3 form items ~339–357)
- Placement discussion decisions: medium universal playbook; Apply Intelligently prohibitions + `@playbook`; S-03 note only; archive in Phase 2

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Playbook and Cursor rule

#### Automated

- [x] 1.1 Foundation playbook exists at context/foundation/interactive-forms.md (~250–350 lines, universal sections) — 24fd50f
- [x] 1.2 Cursor rule exists with Apply Intelligently frontmatter (no globs) and hard prohibitions + @playbook — 24fd50f
- [x] 1.3 Playbook has no S-03 ERB/JS centerpiece section — 24fd50f

#### Manual

- [x] 1.4 Human skim: playbook applies beyond session logging; rule description looks correct in Rules UI — 24fd50f

### Phase 2: Wire discovery, consumer note, close F-04

#### Automated

- [x] 2.1 Root AGENTS.md Architecture pointer to @context/foundation/interactive-forms.md — b8ef52a
- [x] 2.2 log-session-confirm-flow/plan.md note: F-04 playbook path + two nested-form corrections — b8ef52a
- [x] 2.3 change.md and roadmap.md F-04 status updated — b8ef52a
- [x] 2.4 Change archived under context/archive/ via /10x-archive

#### Manual

- [x] 2.5 Human confirm artifacts before archive; smoke-check agent can discover playbook/rule — b8ef52a
