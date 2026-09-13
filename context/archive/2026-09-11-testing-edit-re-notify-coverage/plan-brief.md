# Edit Re-notify Coverage — Plan Brief

> Full plan: `context/changes/testing-edit-re-notify-coverage/plan.md`
> Research: none (planning grounded `Update` fan-out directly from code)

## What & Why

Add who/why test coverage for Risk #5 so score-only edits re-notify selectively and game changes bulk-renotify — no silent stale inbox, no bare notify counts. Opportunistically prove Risk #6 (pending friendship cannot be tagged) on the create path, and fill cookbook §6.2 / §6.6 for Phase 3 of the test plan.

## Starting Point

`GameSessions::Update` already implements selective vs bulk destroy+create re-notify with `update` / `update_after_rejection`. Unit specs are mostly single-friend and count-shaped; request PATCH has persistence/IDOR but no re-notify oracles; integration lifecycle skips post-edit notification asserts; §6.2 still TBD.

## Desired End State

Multi-friend unit + request oracles prove who was re-notified and why; rejected path asserts `update_after_rejection` on both fan-out modes; one pending-friendship create unit example; cookbook teaches the pattern; §3 Phase 3 marked done.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Matrix depth | Multi-friend contrast (2+) | Challenges “any edit ⇒ same path” with peer untouched | Plan |
| Layers | Request + tighten unit; light integration | Matches test-plan types; request mirrors Phase 2 HTTP oracles | Plan |
| `reason` | Assert in who/why oracles | Documents why; catches reason-branch regressions | Plan |
| Risk #6 | One unit create (pending friendship) | Cheap; gate already on create; strangers already covered | Plan |
| Rejection | Both selective and bulk | Same reason rule in both fan-out modes | Plan |
| Stale inbox | Old gone + new unread (recipient/reason) | Matches destroy+create; avoids count-only anti-pattern | Plan |
| Cookbook | §6.2 pattern + §6.6 Phase 3 note | Same close-out shape as Phase 2 | Plan |
| Product code | Fix clear fan-out bugs if oracle independently right | Protection lands; ambiguous → stop and ask | Plan |

## Scope

**In scope:** Unit multi-friend + reason/rejection; request PATCH selective/bulk who/why; light integration lifecycle notify assert; #6 pending unit; cookbook + §3 status; minimal `app/` fix only when oracle is independently right.

**Out of scope:** System specs for edit notify; dedicated #6 phase; `GET /notifications` after every edit; full combinatorial matrix; push/email; weakening oracles to match bugs.

## Architecture / Approach

Test-first layers: unit matrix → request HTTP → integration + cookbook. Oracles always name recipient, reason, pending, and stale→fresh unread; selective examples also prove the untouched peer. Form-shaped `players` params on request examples.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Unit matrix | Multi-friend who/why + rejection reasons + #6 pending | Fixtures assert count instead of who/why |
| 2. Request oracles | PATCH selective + bulk HTTP proofs | Param shape drift vs service unit |
| 3. Integration + cookbook | Lifecycle notify gap closed; §6.2/§6.6/§3 done | Cookbook too vague to copy |

**Prerequisites:** Phase 2 confirm-path cookbook precedent; Postgres + `bin/rspec` green baseline  
**Estimated effort:** ~1–2 sessions across 3 phases

## Open Risks & Assumptions

- No `research.md` — fan-out grounding is from this planning pass; if implementer finds divergence, prefer code + Risk #5 guidance over this brief
- Choosing to fix `app/` on clear failures may expand scope; ambiguous cases must pause

## Success Criteria (Summary)

- Selective score edit re-notifies only the changed friend; game change re-notifies all registered co-players — with reason and fresh unread
- Pending friendship rejected on create at unit layer
- §6.2 teaches the pattern; §3 Phase 3 is `done`
