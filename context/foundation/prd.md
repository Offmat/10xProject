---
project: bgDraft
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

The coordination cost shows up after a session: reconciling who played, scores, and which group the night belonged to is manual and fragmented. A workable product must treat registered players and guests at the same table as normal — not everyone will install the app. Pain category: coordination overhead. Insight: mixed registered + guest players at one session.

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
5. Guest co-player: scorer enters their result without linking to an account.
6. User views their own session statistics with filters.

### Secondary

- User sees a recommended-games list (similar players, games not yet played by user, frequency-weighted scoring) — nice-to-have beyond the primary path.

### Guardrails

- Guest players can always be logged without an account.
- No admin role or admin-only game catalog in MVP.
- Users only see statistics for sessions they participated in.

## User Stories

### US-01: User logs a session with registered and guest players

- **Given** a logged-in user, at least one friend in their circle, and a game from the predefined catalog
- **When** they log a new session, include a registered friend and a guest player with scores, and submit
- **Then** the session is saved, the registered friend receives a notification, guest scores are stored without an account link, and after the friend confirms, the session appears in both users' participations for stats

#### Acceptance Criteria

- Guest player scores persist without requiring signup
- Registered friend can confirm or reject participation from the in-app notification
- Session does not count toward shared stats for the registered friend until they confirm; rejected sessions are excluded

## Functional Requirements

### Authentication

- FR-001: User can create an account and log in. Priority: must-have
  > Socrates: Counter: passwordless invite-only may suffice for first value. Resolution: kept login — friend circle and per-user stats require stable identity.

### Friends

- FR-002: User can add another registered user to their friend circle. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

### Session logging

- FR-003: User can log a played session with game, players, and per-player scores. Priority: must-have
  > Socrates: No counter-argument; it stands as written.
- FR-004: User can enter scores for players who do not have an account (guest players). Priority: must-have
  > Socrates: No counter-argument; it stands as written.
- FR-005: Registered co-player receives an in-app notification when included in a logged session. Priority: must-have
  > Socrates: Counter: push notifications add platform cost for MVP. Resolution: in-app inbox only for v1; no push.
- FR-006: Registered co-player can confirm or reject participation in a logged session. Priority: must-have
  > Socrates: Counter: confirm-only hides wrong scores. Resolution: reject added to MVP alongside confirm.
- FR-009: User can select a game from a predefined catalog when logging a session. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

_Predefined game catalog for MVP: fixed list shipped with the product; no admin or user game creation in v1._

### Statistics

- FR-007: User can view statistics for sessions they participated in, with filters. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

### Recommendations

- FR-008: User can view a recommended-games list (similar players, games the user has not played, frequency-weighted). Priority: nice-to-have
  > Socrates: Counter: cold-start makes recommendations useless in v1. Resolution: kept as nice-to-have; not on primary path.

## Non-Functional Requirements

- **Privacy:** Users only see statistics for sessions they participated in (confirmed or logged).
- **Guest integrity:** Guest players can always be recorded without creating an account.
- **Responsiveness:** Any user-initiated action (log session, confirm/reject, open stats) shows continuous visible feedback within 2 seconds while work continues.

## Business Logic

A logged session becomes part of a registered player's shared history only after they confirm participation; rejection excludes the session from their record; guest players are scored without accounts.

The rule consumes: who logged the session, which registered players were included, confirm/reject responses, and per-player scores (including guests). The output is a single coordinated session record each participant can trust for their own statistics. Users encounter it when logging a game night and when a co-player accepts or rejects inclusion from the in-app inbox.

## Access Control

**Authentication:** login-based accounts (email/password, OAuth, or passwordless — mechanism TBD downstream).

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

1. **Which login mechanism for MVP?** — Shape-notes list email/password, OAuth, or passwordless; exact choice TBD. Owner: user. Block: no (MVP can ship with one path).
2. **How is the predefined game catalog seeded and updated?** — No admin or user game creation in v1; source of initial game list and update process undefined. Owner: user. Block: no for first session log if a minimal seed set exists.
3. **Friend-circle add policy** — One-sided add vs mutual confirmation not specified; FR-002 stands as written. Owner: user. Block: no.
