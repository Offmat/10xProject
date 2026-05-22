---
project: all-aBoard
version: 1
status: draft
created: 2026-05-21
context_type: greenfield
product_type: web-app
target_scale:
  users: medium
  qps: low
  data_volume: small
timeline_budget:
  mvp_weeks: 3
  hard_deadline: null
  after_hours_only: true
---

## Vision & Problem Statement

When recording board game session results, every player keeps their own notes. There is no easy way to share outcomes of games played together across different, overlapping friend groups.

The coordination cost shows up after a session: reconciling who played, scores, and which group the night belonged to is manual and fragmented. A workable product must treat registered players and unregistered players at the same table as normal — not everyone will install the app. Pain category: coordination overhead. Insight: mixed registered + unregistered players at one session.

## User & Persona

**Primary persona:** board-game hobbyist who plays regularly in multiple overlapping friend circles (not a single fixed league).

**Context:** after game nights, they want one place to log sessions, see their own stats, and optionally get lightweight game recommendations — without forcing every opponent to have an account.

## Success Criteria

### Primary

End-to-end flow proves shared session tracking works:

1. User signs up / logs in.
2. User adds another person to their friend circle.
3. User logs a played session: game, players, each player's score.
4. Registered co-player receives an in-app notification and can confirm or reject participation in the session.
5. Unregistered player at the table: scorer enters name and score only (no account; that person does not use the app).
6. User views their own session statistics with filters.

### Secondary

- User sees a recommended-games list (similar players, games not yet played by user, frequency-weighted scoring) — nice-to-have beyond the primary path.

### Guardrails

- Unregistered players (name + score only) can always be included in a session log; they never log in or use the app.
- The user who creates a session log always sees that session in their own history and stats immediately after save, regardless of co-player confirm/reject/pending.
- No admin role or admin-only game catalog in MVP.
- Users only see statistics for sessions they participated in.

## User Stories

### US-01: User logs a session with registered and unregistered players

- **Given** a logged-in user, at least one accepted friend in their circle, and a game from the predefined catalog
- **When** they log a new session, include a registered friend and an unregistered player (name + score only), and submit
- **Then** the session is saved immediately in the logger's history and stats; the registered friend receives an in-app notification; unregistered player data is stored as name and score only (no account); the registered friend's stats include the session only after they confirm

#### Acceptance Criteria

- Unregistered players are stored as name + score only; they do not log in, receive notifications, or have stats in the app
- Logger sees the session in their history and stats immediately after submit, even if a tagged registered friend rejects or never responds
- Registered friend can confirm or reject participation from the in-app notification
- Session does not count toward the registered friend's stats until they confirm; if they reject, the session is excluded from their stats (logger's record is unchanged)

## Functional Requirements

### Authentication

- FR-001: User can create an account and log in. Priority: must-have
  > Socrates: Counter: passwordless invite-only may suffice for first value. Resolution: kept login — friend circle and per-user stats require stable identity.

### Friends

- FR-002: User can send a friend request to another registered user; friendship becomes active after mutual acceptance. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

### Session logging

- FR-003: User can log a played session with game, players, and per-player scores. Priority: must-have
  > Socrates: No counter-argument; it stands as written.
- FR-004: User can enter name and score for unregistered players (people without an account who do not use the app). Priority: must-have
  > Socrates: No counter-argument; it stands as written.
- FR-005: Registered co-player receives an in-app notification when included in a logged session. Priority: must-have
  > Socrates: Counter: push notifications add platform cost for MVP. Resolution: in-app inbox only for v1; no push.
- FR-006: Registered co-player can confirm or reject participation in a logged session. Priority: must-have
  > Socrates: Counter: confirm-only hides wrong scores. Resolution: reject added to MVP alongside confirm.
- FR-009: User can select a game from a predefined catalog when logging a session. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

_Predefined game catalog for MVP: minimal hardcoded list (~20 popular board games) shipped with the product; no admin, user, or runtime catalog editing in v1._

### Statistics

- FR-007: User can view statistics for sessions they participated in, with filters. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

### Recommendations

- FR-008: User can view a recommended-games list (similar players, games the user has not played, frequency-weighted). Priority: nice-to-have
  > Socrates: Counter: cold-start makes recommendations useless in v1. Resolution: kept as nice-to-have; not on primary path.

## Non-Functional Requirements

- **Privacy:** Users only see statistics for sessions they participated in — as the logger who created the record, or as a registered co-player who confirmed participation.
- **Unregistered players:** Unregistered players can always be recorded as name + score only; they never create an account or access the app.
- **Responsiveness:** Any user-initiated action (log session, confirm/reject, open stats) shows continuous visible feedback within 2 seconds while work continues.

## Business Logic

A logged session becomes part of a registered player's shared history only after they confirm participation; rejection excludes the session from their record; unregistered players are recorded as name and score only and never use the app.

**Who sees what:**

| Role | In their history/stats? | Uses the app? |
|------|-------------------------|---------------|
| User who created the log | Yes — immediately on save | Yes |
| Tagged registered co-player | Yes — only after they confirm; no if they reject; pending until they respond | Yes |
| Unregistered player (name + score on the log) | Never — no account, no stats view | No |

The rule consumes: who logged the session, which registered players were included, confirm/reject responses, and per-player scores (including unregistered players). The output is a coordinated session record: the logger's copy is immediate; each tagged registered player gets a copy only on confirm. Users encounter it when logging a game night and when a co-player accepts or rejects inclusion from the in-app inbox.

## Access Control

**Authentication:** email + password for MVP. OAuth and passwordless sign-in are out of scope for v1.

**Friends:** mutual confirmation — a user sends a friend request; the other user accepts or declines; the friend circle link is active only after acceptance.

**Roles (MVP):** flat user model only. Every registered user has the same capabilities; no admin role in MVP.

**Post-MVP:** admin capabilities (e.g. curating game catalog) explicitly deferred — not part of first shippable version.

## Non-Goals

- **Avoid: per-game ratings** — no star scores on games in MVP.
- **Avoid: admin account** — flat users only; no admin role.
- **Avoid: users or admins adding new games to the catalog** — predefined catalog only in v1.
- **Avoid: complex recommendation algorithms** — simple frequency-weighted nice-to-have at most; not a recommender system.
- **Avoid: push notifications** — in-app inbox only.
- **Avoid: external game database integration** — no third-party game lookup in v1.
- **Avoid: team workspaces / formal league management** — friend circles, not org-style leagues.

## Open Questions

_All resolved 2026-05-21._

1. **Login mechanism** — **Resolved:** email + password for MVP.
2. **Game catalog seeding** — **Resolved:** minimal hardcoded list (~20 popular board games) in the app; catalog changes require a new release (no admin UI, no user-added games).
3. **Friend-circle add policy** — **Resolved:** mutual confirmation (request → accept/decline).
