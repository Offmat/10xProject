---
date: 2026-08-02T19:58:35+02:00
researcher: Mateusz Leśniak
git_commit: 1fc2a2fa88f675b730f884723431cd60d2b1f3f7
branch: main
repository: 10xProject
topic: "Defend confirm/reject semantics and IDOR on session/notification actions (test-plan §3 Phase 2)"
tags: [research, codebase, notifications, game-sessions, idor, confirm-reject, visible-to, test-plan-phase-2]
status: complete
last_updated: 2026-08-02
last_updated_by: Mateusz Leśniak
---

# Research: Confirm path & ownership (test-plan §3 Phase 2)

**Date**: 2026-08-02T19:58:35+02:00
**Researcher**: Mateusz Leśniak
**Git Commit**: 1fc2a2fa88f675b730f884723431cd60d2b1f3f7
**Branch**: main
**Repository**: 10xProject

## Research Question

Where do confirm/reject semantics and ownership (IDOR) live for session/notification actions, and what must Phase 2 tests prove for Risks #3 and #4?

## Summary

Confirm/reject is a **notification-gated state machine** on `GameSessionParticipant` (`pending` → `confirmed` / `rejected`), not a game-session controller action. Co-player history inclusion is a single scope — `GameSession.visible_to` — which always includes the logger (`creator`) and includes a tagged friend only when their participant row is `confirmed`. Dedicated stats (roadmap S-04) do not exist yet; that scope is the oracle for Risk #3 today.

IDOR protection already uses **scoped ActiveRecord finds** (no Pundit): notifications via `unread.for_user(current_user)`, sessions via `visible_to` / `created_by`. Failures raise `RecordNotFound` → **HTTP 404**. Classic bare-ID mutation is not present. Phase 2 work is primarily **stronger request oracles** (confirm/reject ↔ friend’s `GET /game_sessions`; foreign-id acts assert **resource unchanged**) and filling cookbook §6.5 — mirroring the friendships IDOR pattern — not greenfield product defense.

## Detailed Findings

### Confirm / reject state machine

- Enum and mutations: [`app/models/game_session_participant.rb`](https://github.com/Offmat/10xProject/blob/1fc2a2fa88f675b730f884723431cd60d2b1f3f7/app/models/game_session_participant.rb) — `pending: 0, confirmed: 1, rejected: 2`; `confirm!` / `reject!` are unconditional `update!` (no prior-state guard on the model).
- HTTP entry points only: `PATCH /notifications/:id/confirm` and `.../reject` ([`config/routes.rb`](https://github.com/Offmat/10xProject/blob/1fc2a2fa88f675b730f884723431cd60d2b1f3f7/config/routes.rb) L12–16). No confirm/reject on `game_sessions`.
- Controller guard ([`notifications_controller.rb`](https://github.com/Offmat/10xProject/blob/1fc2a2fa88f675b730f884723431cd60d2b1f3f7/app/controllers/notifications_controller.rb#L24-L28)): `Notification.unread.for_user(current_user).find(id)` **and** `notifiable.pending?`, else `RecordNotFound`. Then `confirm!`/`reject!` + `mark_as_read!`.
- Initial status on create ([`GameSessions::Create`](https://github.com/Offmat/10xProject/blob/1fc2a2fa88f675b730f884723431cd60d2b1f3f7/app/services/game_sessions/create.rb)): logger and guests → `confirmed`; tagged friends → `pending` + invitation notification. Update can reset non-logger friends to `pending` and re-notify ([`GameSessions::Update`](https://github.com/Offmat/10xProject/blob/1fc2a2fa88f675b730f884723431cd60d2b1f3f7/app/services/game_sessions/update.rb)).
- There is **no** dedicated Confirm/Reject service class.

```
Create/Update (friend tagged or re-notified)
        │
        ▼
     pending ──PATCH confirm──► confirmed
        │
        └──PATCH reject──► rejected

Edit (score/game) can return friend to pending + new unread notification.
Double confirm / reject-after-confirm / foreign id → 404 (controller guard).
```

### History / “stats” inclusion (Risk #3)

- Single rule ([`game_session.rb` L6–11](https://github.com/Offmat/10xProject/blob/1fc2a2fa88f675b730f884723431cd60d2b1f3f7/app/models/game_session.rb#L6-L11)):

  | Actor | Included when |
  |-------|----------------|
  | Logger | Always (`creator: user`), regardless of co-player status |
  | Co-player | Only if `GameSessionParticipant.confirmed` for that user |
  | Pending / rejected friend | Excluded |
  | Guest | Auto-confirmed but `user_id` nil → never own history |

- Consumers: `GameSessionsController#index` and `#show` both use `visible_to`. Edit/update use stricter `created_by`.
- **No stats feature yet** (S-04). Risk #3’s “stats” oracle today = friend history list via `visible_to` / `GET /game_sessions`.
- Footgun for S-04: `User#game_session_participations` is unscoped — must not drive aggregates without `.confirmed` + creator OR.

### Ownership / IDOR (Risk #4)

- No policy framework; scoped finds only (same idiom as friendships).
- Session show: `visible_to(current_user).find` → 404. Edit/update: `created_by(current_user).find` → 404. Confirmed co-player can show, not edit.
- Notification confirm/reject: `unread.for_user` + pending → 404. Unauthenticated → redirect to sign-in (never 403).
- Implementation already blocks classic IDOR. Spec gaps vs friendships gold standard: foreign notification confirm/reject and non-creator session update assert **404** but often omit **target resource unchanged**.

### Existing coverage vs Phase 2 gaps

**Already shipped** (largely by `log-session-confirm-flow`):

- Request: confirm/reject happy path, foreign-id 404, already-read 404 + status unchanged — `spec/requests/notifications_spec.rb`
- Request: session show/edit/update non-owner 404 — `spec/requests/game_sessions_spec.rb`
- Model `visible_to` matrix — `spec/models/game_session_spec.rb`
- Integration confirm → visible; reject → excluded; logger always — `spec/services/integration/game_sessions_spec.rb`

**Gaps for Phase 2 (test oracles, not product rewrites):**

| Risk | Missing oracle |
|------|----------------|
| #3 | Request-level: after PATCH confirm/reject, friend’s `GET /game_sessions` includes/excludes; logger still sees after friend rejects; pending friend never listed |
| #4 | Foreign notification confirm/reject → 404 **and** participant + notification unchanged; optionally session update IDOR → attrs unchanged |
| Cookbook | `test-plan.md` §6.5 still TBD |

## Code References

- `app/models/game_session.rb:6-11` — `created_by` / `visible_to` inclusion rule
- `app/models/game_session_participant.rb:6,12-18` — status enum; `confirm!` / `reject!`
- `app/models/notification.rb:9-14` — `unread`, `for_user`, `mark_as_read!`
- `app/controllers/notifications_controller.rb:8-28` — confirm/reject + actionable guard
- `app/controllers/game_sessions_controller.rb:2-11,49,54` — list/show `visible_to`; edit/update `created_by`
- `app/services/game_sessions/create.rb:47-79` — initial statuses + invite
- `app/services/game_sessions/update.rb:94-136` — reset to pending + re-notify
- `spec/requests/notifications_spec.rb:44-121` — confirm/reject + partial IDOR
- `spec/requests/friendships_spec.rb:66-120` — gold-standard IDOR (404 + unchanged)
- `spec/services/integration/game_sessions_spec.rb:12-87` — lifecycle visibility

## Architecture Insights

1. **Authorization = scoped find → 404**, consistent across friendships, sessions, and notifications. Prefer mirroring that contract in specs rather than introducing 403/Pundit in this phase.
2. **History inclusion is one scope.** Phase 2 should treat `GameSession.visible_to` (and the HTTP index that uses it) as the Risk #3 ground truth — not notification open/read alone.
3. **Model mutations are trust-the-caller;** only the controller enforces pending + ownership. Service/unit tests of `confirm!` alone do not prove the HTTP security boundary.
4. **Stats will inherit this contract** when S-04 lands; Phase 2 cookbook should document “reuse `visible_to`” so aggregates do not invent a second filter.

## Historical Context (from prior changes)

- `context/changes/log-session-confirm-flow/` — shipped confirm flow, notification request specs, session IDOR 404s; impl-review F4 tightened unread+pending gate. Deferred `played_at`/stats to S-04; left stronger history/IDOR oracles for this phase.
- `context/archive/2026-07-14-mutual-friend-circle/` — established scoped-find → 404 + assert resource unchanged; plan cites IDOR contract explicitly; live pattern in `friendships_controller.rb` + `friendships_spec.rb`.
- `context/foundation/test-plan.md` §2–3 — Risks #3–#4; Phase 2 goal; research must ground confirm state machine, stats inclusion, and ownership checks.

## Related Research

- `context/archive/2026-07-14-mutual-friend-circle/research.md` — friend-circle authorization / IDOR pattern
- No prior `research.md` under `log-session-confirm-flow` (plan-only change)

## Open Questions

1. Should Phase 2 also add a single request example “friend rejects → logger `GET /game_sessions` still includes session,” or is the existing integration example enough once HTTP confirm/reject ↔ history is covered?
2. Is asserting notification `read_at` / participant status unchanged on foreign-id enough for Risk #4, or should session update IDOR also assert attribute equality (friendships-style)?
3. When S-04 stats land, should cookbook §6.5 explicitly forbid using `user.game_session_participations` without `.confirmed` — or is that out of Phase 2 scope?
