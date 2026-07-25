---
change_id: rails-interactive-forms-guide
title: Rails interactive forms guide
status: impl_reviewed
created: 2026-07-25
updated: 2026-07-25
archived_at: null
---

## Notes

<!-- Free-form notes for this change: links, ad-hoc context, decisions that don't belong in research/frame/plan. -->

- 2026-07-25: `research.md` written. Evidence base includes locally cloned reference repos (deleted after the research): `basecamp/fizzy@9ae6b3b`, `basecamp/once-campfire@69e8cd7`, `hotwired/stimulus@6446f69`, `hotwired/turbo@f3faa2d`, `hotwired/turbo-rails@37530c0`. Re-clone with `git clone --depth 1` if a citation needs re-checking.
- Two corrections to the S-03 plan's `nested-form` contract came out of the research: row indices must be **unique and numeric** (not bare `Date.now()`), and the per-row friend/guest toggle needs its **own controller identifier** rather than living in the container controller. See `research.md` §7.1, §7.2, §14. F-04 plan leaves a **note only** on `log-session-confirm-flow/plan.md` (no Phase 3 rewrite).
- Planning decisions: medium **stack-universal** foundation playbook (not S-03-centric); Apply Intelligently Cursor rule (prohibitions + `@playbook`); root AGENTS pointer; archive in Phase 2 after human confirm. See `plan.md` / `plan-brief.md`.
- Living surfaces (Phase 1–2): playbook `context/foundation/interactive-forms.md`; Cursor rule `.cursor/rules/hotwire-interactive-forms.mdc`; root `AGENTS.md` Guides pointer; S-03 consumer note on `log-session-confirm-flow/plan.md`.
- 2026-07-25: `/10x-impl-review` APPROVED (`reviews/impl-review.md`). F1 (Guides placement) accepted via plan amend; F2 status → `impl_reviewed`.
