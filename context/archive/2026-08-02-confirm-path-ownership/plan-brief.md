# Confirm Path & Ownership — Plan Brief

> Full plan: `context/changes/confirm-path-ownership/plan.md`
> Research: `context/changes/confirm-path-ownership/research.md`

## What & Why

Defend test-plan Risks #3–#4 at the request layer: confirm/reject must steer co-player history correctly, and foreign IDs must not mutate another user’s session, notification, or friendship. Product scoped-find guards already exist; this change strengthens oracles and documents them.

## Starting Point

Confirm/reject and session IDOR mostly assert status or 404 only. Friendships already assert 404 + unchanged. History inclusion is `GameSession.visible_to` / `GET /game_sessions` (no stats UI yet). Cookbook §6.5 is TBD.

## Desired End State

Request specs prove the full pending/confirm/reject/logger history matrix over HTTP, and every covered foreign-id mutation leaves the target unchanged. Cookbook §6.5 (plus light foundation notes) teaches the pattern, including that friendship IDOR oracles were aligned here.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Scope | Specs + cookbook; fix `app/` only if oracle fails | Defense already in place; Phase 2 is oracle strength | Plan |
| Risk #3 depth | Confirm/reject/pending/logger all at request layer | Closes HTTP gap vs model/integration-only | Plan |
| Risk #4 depth | Notifications + session update + friendships | Session and notification named by risk; friendships minimal align | Plan (user) |
| Friendships | In this change_id, not a follow-up | Delta is small; keep one IDOR contract | Plan (user) |
| Cookbook | Fill §6.5 + S-04 `visible_to` note; light §6.1–6.2 / §6.6 | Phase 2 owns these slots; warn against unscoped participations | Plan |
| Auth style | Keep 404 scoped-find; no Pundit/403 | Matches current app and prior friend-circle work | Research |

## Scope

**In scope:** Request oracles for Risks #3–#4; minimal friendship IDOR alignment; `test-plan.md` cookbook + Phase 2 status; optional one-liner in `spec/AGENTS.md`; minimal `app/` bugfix if oracles go red.

**Out of scope:** Pundit, S-04 stats, system specs, edit re-notify (Phase 3), revoke-after-confirm, broad friendship features.

## Architecture / Approach

Extend `notifications_spec` / `game_sessions_spec` for history and unchanged oracles; align `friendships_spec` to the same contract; document in foundation cookbook. No new endpoints.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Risk #3 history oracles | Confirm/reject/pending/logger ↔ `GET /game_sessions` | Flaky body asserts if game names collide |
| 2. Risk #4 unchanged oracles | 404 + unchanged on notifications, sessions, friendships | Surprises a real `app/` bug — fix, don’t weaken |
| 3. Cookbook + foundation notes | §6.5 filled; Phase 2 status; friendship note | Doc drift if status updated before specs land |

**Prerequisites:** Research complete; existing confirm-flow request specs green.
**Estimated effort:** ~1 session across 3 phases.

## Open Risks & Assumptions

- New oracles may expose a product bug; plan allows a minimal `app/` fix without expanding into auth redesign
- Index body assertions depend on distinctive game names in fixtures
- S-04 still future — cookbook note is preventive, not enforced by code yet

## Success Criteria (Summary)

- Friend confirm → listed; reject/pending → not; logger still listed after reject (HTTP)
- Foreign notification/session/friendship mutations → 404 and target unchanged
- Contributor can follow §6.5 without reading research
