# Mutual Friend Circle (S-02) — Plan Brief

> Full plan: `context/changes/mutual-friend-circle/plan.md`
> Research: `context/changes/mutual-friend-circle/research.md`

## What & Why

Build roadmap slice **S-02**: a registered user sends a friend request to another registered user by email; the addressee accepts or declines; the friendship is active only after mutual acceptance. This is the last prerequisite for the north star **S-03** (log a session tagging a registered friend), which requires at least one accepted friend.

## Starting Point

Greenfield for this domain. The schema has only `users`, auth `sessions`, and `games`; routes are auth + catalog only. No `Friendship` model, no friends UI, no notification infrastructure exists. Auth, registration, and daisyUI layout/nav are already in place and set the conventions to follow.

## Desired End State

Two users can establish a mutual friendship entirely through the UI: A adds B by email; B sees a nav badge + an incoming request and accepts or declines; on accept each appears in the other's Active friends. A can cancel a pending request, re-send after a decline, and a reciprocal request auto-accepts. All served from one `/friends` page.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Relationship storage | One row per relationship, `enum status: {pending, accepted, declined}`, unique ordered-pair index | Canonical Rails shape; "active friends" = accepted rows on either side | Research |
| Notifications | No `Notification` table — inbox + badge are derived queries | A pending incoming request *is* the notification; defer generic inbox to S-03 | Research |
| Friend discovery | Exact email lookup | No usernames exist; smallest UI; mirrors auth norms | Plan |
| Reciprocal request | Auto-accept the existing pending request | Mutual intent is obvious; avoids a dead-end error | Plan |
| Re-request after decline | Allowed — reuse the same row (flip declined→pending) | Honors unique index, keeps history, supports reconciliation | Plan |
| Declined rows | Kept as `declined` | Enables re-request reuse + audit trail | Plan |
| Cancel pending | Requester can withdraw a pending outgoing request | Expected UX; cheap single action | Plan |
| Unfriend | Deferred (traced to roadmap Parked) | Keeps S-02 focused; PRD doesn't require it | Plan |
| UI layout | One `/friends` page, three sections + add form | Simple MVP mental model, one index action | Plan |
| Nav badge | Yes — incoming pending count on Friends link | The in-app notification signal; cheap query | Plan |
| Add-by-email errors | Fully distinct messages incl. "no such user" | Explicit product call (diverges from anti-enumeration) | Plan |

## Scope

**In scope:** `friendships` table + model; send-by-email / accept / decline / cancel; reciprocal auto-accept; decline-row reuse; `/friends` page; nav badge; authorization (IDOR guards).

**Out of scope:** unfriend/remove, blocking, `Notification` table, guest/participant schema (S-03), email/push notifications, usernames, re-request rate limiting.

## Architecture / Approach

`Friendship` model (enum + scopes + self-friend validation) with `User` associations. The only non-trivial logic — the send-request branching (lookup, guards, reciprocal auto-accept, declined-row reuse) — lives in a `Friendships::CreateRequest` service (`.call`). A thin `FriendshipsController` (index/create/accept/decline/destroy) authorizes by scoping finds to the current user (`incoming_for` for accept/decline, `outgoing_for` for cancel), so non-participants get 404. Views and nav mirror the existing daisyUI auth pages.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Data model | `friendships` migration, `Friendship` model + scopes, `User` associations | Ordered-pair unique index vs symmetric "friends" query |
| 2. Request flow | Routes, `CreateRequest` service, controller w/ authorization | Reciprocal auto-accept & declined-row reuse vs unique index; IDOR guards |
| 3. UI + docs | `/friends` page, nav badge, distinct flash, roadmap trace | Correct per-user scoping in views; badge count |

**Prerequisites:** S-01 (auth) — done. No new gems.
**Estimated effort:** ~2-3 focused sessions across 3 phases.

## Open Risks & Assumptions

- **Enumeration divergence (accepted):** distinct "no account found" message lets users probe registered emails; revisit if abuse appears.
- **No re-request rate limit:** decline→re-request has no cooldown; add later if pestering becomes an issue.
- **Assumption:** email is the only stable identifier, so exact-email lookup is the discovery mechanism.

## Success Criteria (Summary)

- A user can send, accept, decline, and cancel friend requests, and sees active friends — end-to-end in the browser.
- A registered user is notified of incoming requests via the nav badge + inbox list (no notification table).
- A non-participant cannot act on someone else's request (404), verified by request specs.
