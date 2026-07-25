---
change_id: rails-interactive-forms-guide
title: Rails interactive forms guide
status: preparing
created: 2026-07-25
updated: 2026-07-25
archived_at: null
---

## Notes

<!-- Free-form notes for this change: links, ad-hoc context, decisions that don't belong in research/frame/plan. -->

- 2026-07-25: `research.md` written. Evidence base includes locally cloned reference repos (deleted after the research): `basecamp/fizzy@9ae6b3b`, `basecamp/once-campfire@69e8cd7`, `hotwired/stimulus@6446f69`, `hotwired/turbo@f3faa2d`, `hotwired/turbo-rails@37530c0`. Re-clone with `git clone --depth 1` if a citation needs re-checking.
- Two corrections to the S-03 plan's `nested-form` contract came out of the research: row indices must be **unique and numeric** (not bare `Date.now()`), and the per-row friend/guest toggle needs its **own controller identifier** rather than living in the container controller. See `research.md` §7.1, §7.2, §14.
