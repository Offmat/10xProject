---
change_id: testing-edit-re-notify-coverage
title: Edit re-notify coverage for test rollout Phase 3
status: archived
created: 2026-09-11
updated: 2026-09-13
archived_at: 2026-09-13T14:31:27Z
---

## Notes

Open a change folder for rollout Phase 3 of context/foundation/test-plan.md: "Edit re-notify coverage".
Risks covered: #5 (Edit after log: selective vs bulk re-notify wrong → co-players act on stale scores/game); #6 only if cheap on create path (opportunistic).
Test types planned: request + service integration.
Risk response intent:
- #5: prove score-only edit re-notifies selectively and game change bulk-renotifies; no silent stale inbox; challenge "Any edit ⇒ same notify path"; avoid asserting notify count without who/why. Research must ground edit classification and notify fan-out rules.
- #6: prove non-accepted friend cannot be tagged as registered co-player — only if already cheap on the create path; do not open a dedicated phase for this risk.
After creating the folder, follow the downstream continuation rule.
