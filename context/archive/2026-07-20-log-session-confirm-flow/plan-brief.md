# Log Session with Confirm Flow — Plan Brief

> Full plan: `context/changes/log-session-confirm-flow/plan.md`

## What & Why

S-03 is the project's north star — the smallest end-to-end slice that proves the core hypothesis: shared session tracking with optional co-player consent. A user logs a board-game session with a catalog game, their own score, and a mix of registered friends and unregistered guests. Each registered friend gets an in-app notification and can confirm or reject. The logger sees their session immediately; friends see it only after confirming. Sessions can be edited, with only affected participants re-notified.

## Starting Point

Auth (S-01), mutual friendships (S-02), the game catalog (F-02), and the UI foundation (F-03) are all in place. The codebase has 4 tables (users, auth sessions, games, friendships), service conventions (`.call` + `Data.define`), and daisyUI styling — but zero game-session infrastructure. There is no notification table; friend requests use derived queries. The Stimulus scaffold exists but has no custom controllers.

## Desired End State

A logged-in user can create, view, and edit game sessions from the UI. Each session shows a game, per-player scores, and participation status. Tagged friends receive in-app notifications and can confirm or reject from a dedicated inbox. The nav displays badges for unread notifications. All business rules (friendship validation, confirm/reject state machine, edit re-notification, privacy scoping) are covered by automated specs.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) |
|----------|--------|-------------------|
| Game-session model name | `GameSession` (not `Session`) | Auth `Session` model occupies the name; `GameSession` is unambiguous in code and DB. |
| Notification architecture | Polymorphic `Notification` model | Single inbox scales to future notification types; supports read/unread tracking cleanly. |
| Participant storage | Single table with CHECK constraint | One row per player; nullable `user_id` OR `guest_name` with DB-level enforcement. |
| Score format | Integer, required | Covers most board games; future win/lose support parked in roadmap. |
| Dynamic form approach | Stimulus controller + HTML `<template>` | Instant UX, ~20 lines JS, standard Hotwire pattern; first custom Stimulus controller. |
| Player type selection | Toggle per row (Friend / Guest) | Explicit mental model; prevents ambiguity between friend and guest entries. |
| Inbox location | Dedicated `/notifications` page + nav badge | Clean separation; friend-request inbox stays on `/friendships` for MVP. |
| Edit behavior | Selective re-notification (changed participants only) | Minimal disruption; only affected players re-confirm. Game change resets all. |
| Unfriend cascade | No cascade | Pending participations survive unfriending; sessions are historical records. |
| Session mutability | Edit allowed, delete not allowed | Fixes mistakes without complex deletion logic; re-notification handles data integrity. |
| Logger role | Always a confirmed participant with a score | Simplifies the model; matches PRD flow. |
| Minimum session size | 1 player (logger only) | Solo sessions allowed for flexibility. |

## Scope

**In scope:** Session CRUD (create, read, edit), participant management (friends + guests), confirm/reject flow, polymorphic notifications with inbox, nav badge, Stimulus nested form, session history list, request + service + model specs.

**Out of scope:** Session deletion, real-time updates, date picker, comments/notes, photos, ratings, push notifications, friend-request inbox unification, bulk import, revocation of confirmed participation.

## Architecture / Approach

Three new tables (`game_sessions`, `game_session_participants`, `notifications`) join the existing schema. `GameSession` belongs to a `User` (creator) and `Game`. `GameSessionParticipant` uses a single-table design with a CHECK constraint for mixed registered/guest players. `Notification` is polymorphic (points at `GameSessionParticipant`). Two services (`GameSessions::Create`, `GameSessions::Update`) orchestrate all business logic — controllers stay thin. A Stimulus `nested_form_controller` manages dynamic player rows on the form.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|-----------------|----------|
| 1. Data Model Foundation | 3 migrations, 3 models, associations, factories, model specs | CHECK constraint syntax; `visible_to` scope correctness |
| 2. Business Logic Services | Create/Update services, confirm/reject, integration specs | Edit diff logic complexity; re-notification edge cases |
| 3. Controllers, Routes, Views, Stimulus | Full CRUD, inbox, dynamic form, nav badge, request specs | First Stimulus controller; form state management with toggles |

**Prerequisites:** S-02 (friendships) and F-02 (game catalog) both done.
**Estimated effort:** ~3 sessions across 3 phases.

## Open Risks & Assumptions

- First custom Stimulus controller — no prior art in the codebase to copy from; may need iteration on the nested-form pattern
- Edit re-notification diff logic is the most complex service in the codebase so far — thorough integration specs are critical
- `visible_to` scope correctness directly affects privacy (who sees which sessions); model spec must cover all combinations
- Notification count runs on every authenticated request — acceptable for MVP volumes but may need caching at scale

## Success Criteria (Summary)

- A user can log a session with a catalog game, friends, and guests — and see it immediately in their history
- A tagged friend can confirm or reject from the notification inbox — confirmed sessions appear in their history, rejected do not
- Editing a session re-notifies only affected participants
