---
date: 2026-07-14T23:26:30+0200
researcher: mateuszlesniak
git_commit: 804c77a5550b840c86a962fb01de1d77b03f6149
branch: main
repository: 10xProject
topic: "Storing/promoting unregistered players (identity resolution) and handling friend-request notifications"
tags: [research, codebase, friendships, notifications, guest-players, identity-resolution, mvp-scope]
status: complete
last_updated: 2026-07-14
last_updated_by: mateuszlesniak
---

# Research: unregistered-player storage + promotion, and friend-request notifications

**Date**: 2026-07-14T23:26:30+0200
**Researcher**: mateuszlesniak
**Git Commit**: 804c77a5550b840c86a962fb01de1d77b03f6149
**Branch**: main
**Repository**: 10xProject

## Research Question

1. How to store representations of non-registered users so it would be possible to later transform them into registered users? Is it worth trying? There could be multiple entities representing the same real person (multiple users log sessions and each adds an "NPC" that is actually the same person). Is there a way to handle this in reasonable time, or better to drop it now? Maybe users will just edit a session and swap an NPC for a user after they register?
2. How to properly handle friend-request notifications?

## Summary

**Scope note.** This research is opened under the `mutual-friend-circle` change (roadmap **S-02**, `roadmap.md:121`). Friend-request notifications are squarely S-02. Guest/unregistered-player storage is technically **S-03** (`log-session-with-confirm`, `roadmap.md:133`), but it is researched here because the S-02 schema (friendships + how we model "a person in a session") should not paint S-03 into a corner. Both domains are **greenfield** — nothing exists in code yet.

**On unregistered-player identity resolution — recommendation: drop it for the MVP.** The PRD is explicit and repeated: unregistered players are "name + score only … they never log in, receive notifications, or have stats in the app" (`prd.md:66-67, 111, 124`). "Transforming an NPC into a registered user" and "deduping the same real person across sessions logged by different users" is **entity resolution** — a genuinely hard problem with no cheap correct solution, and it delivers zero value against the primary Success Criteria. With `main_goal: speed` and `top_blocker: time` on a 3-week after-hours MVP (`tech-stack.md`, `roadmap.md:8-9`), the correct move is to **not build cross-user identity resolution now**, but to **choose a participant schema that keeps promotion a cheap additive migration later**. The user's own instinct — "edit the session and swap the NPC for the user after they register" — is exactly the right cheap path, and the schema below makes it a one-line update.

**On friend-request notifications — recommendation: do NOT build a generic Notification model for S-02.** A friend request *is* its own inbox: a `friendships` row with `status: pending` where `addressee_id = current_user`. The "incoming requests" list is a query, not a separate notification record. Building a polymorphic `Notification` table now would be speculative infra ahead of its second consumer (S-03's session-confirm inbox). Defer the shared inbox to S-03 when there are two real notification types to generalize over.

## Detailed Findings

### Current persistence state (everything below is greenfield)

Schema version `2026_06_07_120000`; only three domain tables exist ([db/schema.rb:13-53](db/schema.rb)):

- `users` — `email`, `password_digest` ([app/models/user.rb:1-10](app/models/user.rb))
- `sessions` — **auth** login sessions, `belongs_to :user`, 30-day lifetime + `sweep` ([app/models/session.rb:1-12](app/models/session.rb)). NB: this is the login cookie store, **not** a game-night model. Naming collision to avoid in S-03 — do not call the game-night model `Session`.
- `games` — Wikidata-imported catalog ([app/models/game.rb:1-21](app/models/game.rb))

Confirmed **absent** in code: any `Friendship`/`FriendRequest`, `Notification`, `GameSession`/`Play`, `Player`/`Participant`/`GuestPlayer`. Routes are auth + catalog only ([config/routes.rb:1-16](config/routes.rb)). The `mutual-friend-circle` change had only its `change.md` identity stub before this research.

### Established repo conventions to follow (from the two archived slices)

- **Migrations**: domain columns first, `t.timestamps`, indexes via `add_index` after the block ([db/migrate/20260602150526_create_users.rb:1-10](db/migrate/20260602150526_create_users.rb)).
- **Models**: inline `validates`, `normalizes`, associations; no fat business-logic callbacks ([app/models/user.rb](app/models/user.rb), [app/models/game.rb](app/models/game.rb)).
- **Controllers**: default auth via `Authentication` concern; `allow_unauthenticated_access` only for public actions; thin actions; strong params in a private method ([app/controllers/sessions_controller.rb](app/controllers/sessions_controller.rb)). Rule from `app/AGENTS.md:24-27`: domain code must not read `Current`/cookies — pass `current_user` in explicitly.
- **Services**: namespaced under `app/services/<domain>/`, single public `.call`; no `ApplicationService` base until 5+ services share boilerplate (`app/AGENTS.md:34-42`). Orchestrator example: [app/services/game_catalog/import_service.rb:1-26](app/services/game_catalog/import_service.rb).
- **Specs**: request specs are the primary HTTP surface; `spec/services/unit` (stubbed) vs `spec/services/integration` (real DB) split (`spec/AGENTS.md:14-20`). The **session-log + confirm integration path is already anticipated** in the spec layout but unimplemented.

---

### Part 1 — Unregistered players: storage, promotion, and the identity problem

#### 1a. Why "same real person across sessions" is genuinely hard

The problem the question describes — user A logs a night and types guest "Kuba"; user B logs a different night and types guest "Kuba"; are they the same Kuba? — is **entity resolution / record linkage**. With only a free-text name there is *no* reliable signal to merge them (names collide, spellings vary, no shared key). Any automatic merge is either wrong (false merges of different people) or useless (never merges). The only *correct* ways to establish "these two guest rows are the same person" are:

1. The real person eventually **registers and self-claims** the rows (needs an invite/claim mechanism), or
2. A human **manually asserts** the identity (the "edit session, swap NPC → user" path).

Both require a human decision. There is no reasonable-time automatic solution, so **do not attempt automatic cross-user dedup in the MVP**. This matches the PRD, which never promises guest identity continuity — guests are `name + score only`, per-session, no stats (`prd.md:50, 66-67, 124`; `shape-notes.md:134`).

#### 1b. The one cheap decision that matters now: model "a participant" as a single join row that can be *either* registered *or* guest

The test-plan already anticipates this shape: "guest rows: name + score only, no user FK; distinguishable from registered tags" and "NPC-only sessions skip the friend check" (`test-plan.md:47, 48, 59-60`). That points to one join table (call it `session_players` / `participants`) per game-night with:

```ruby
# S-03 territory — shown here only so S-02 doesn't conflict with it
create_table :session_players do |t|
  t.references :game_session, null: false, foreign_key: true
  t.references :user, null: true, foreign_key: true   # set  => registered co-player
  t.string  :guest_name, null: true                   # set  => unregistered guest
  t.integer :score
  t.integer :status, null: false, default: 0          # pending/confirmed/rejected (registered only)
  t.timestamps
end
# CHECK: exactly one of (user_id, guest_name) present
```

Key property: **a guest is just a row with `user_id IS NULL` and a `guest_name`.** "Promoting" that guest to a registered user later is then a *single additive update* — set `user_id`, null out `guest_name`, set `status` — no schema migration, no data backfill machinery. This is the user's "edit the session and swap the NPC for a user" idea, and this schema makes it free. **Reserve `user_id` as nullable now (in S-03); do not add a separate `GuestPlayer` table.**

#### 1c. Spectrum of options for guest storage/promotion (cheapest → most expensive)

| Option | What it is | Promotion path | Identity dedup | MVP fit |
|---|---|---|---|---|
| **0. Inline, PRD-literal** | `guest_name` + `score` on the participant row, per session, no reuse | Manual edit/swap of that one row | None | ✅ Ship this |
| **1. Per-logger guest autocomplete** | Same rows, plus a query that suggests names the *same logger* typed before | Manual swap; can bulk-swap the logger's own rows | Within one user's own guests only (still just string match, user-confirmed) | ⚠️ Nice-to-have, defer |
| **2. First-class `Guest` entity owned by a user** | A `guests` table (owner + name), referenced by participants; promotable via `claimed_by_user_id` | Guest registers → claim token → rows relink | Per-owner identity, not cross-user | ❌ Over-scope for MVP |
| **3. Full entity resolution / merge** | Cross-user "this NPC == that NPC == this User" graph, merge tooling | Admin/user merge UI + retroactive stat recompute | Attempted cross-user | ❌ Out of scope; hard problem |

**Recommendation: Option 0 for the MVP, with the Option-0 schema deliberately being a subset of the row shape in 1b so Option 1 is a later additive feature, not a rewrite.** If a guest ever needs to "become" a user, the manual **edit-session-swap** is the supported path. Note one product consequence to raise in S-03 planning: swapping a guest → registered user should re-enter the confirm/reject flow (the newly-tagged user must confirm before it counts toward *their* stats, per `prd.md:69`), while the logger's record is unchanged.

#### 1d. Is it worth trying? — verdict

**No, not in the MVP.** Building promotion/identity-resolution now costs disproportionate time (claim tokens, merge logic, retroactive stats, ambiguity UX) against `speed`/`time` constraints, and the PRD explicitly scopes guests out of identity/stats. The *cheap insurance* — a nullable `user_id` on the participant row (decided in S-03, not S-02) — preserves the manual-swap escape hatch for ~zero cost. Anything beyond that is post-MVP (it would sit naturally next to a future "claim your guest history" feature; none is on the roadmap).

---

### Part 2 — Friend-request notifications

#### 2a. Friendship model (this is the S-02 deliverable)

PRD/roadmap require: send a request → other user accepts or declines → link active only after mutual acceptance (`prd.md:80, 132, 155`; `roadmap.md:121-131`). Canonical Rails shape — **one row per relationship** with a state, not two mirrored rows:

```ruby
create_table :friendships do |t|
  t.references :requester, null: false, foreign_key: { to_table: :users }
  t.references :addressee, null: false, foreign_key: { to_table: :users }
  t.integer :status, null: false, default: 0   # enum: pending / accepted / declined
  t.timestamps
end
add_index :friendships, [:requester_id, :addressee_id], unique: true
# guard against self-friend and against A→B + B→A duplicates (model-level validate)
```

- `enum status: { pending: 0, accepted: 1, declined: 2 }`.
- "My active friends" = accepted rows where I am *either* side (scope over `requester_id = me OR addressee_id = me`).
- Uniqueness on the ordered pair; add a model validation to reject the reciprocal duplicate (B requesting A when A→B already exists) and self-requests.
- Declining sets `status: declined` (keep the row for audit / to allow re-request policy) rather than deleting — decide the re-request rule during `/10x-plan`.

#### 2b. The notification: derive it, don't store it (for S-02)

A pending incoming friend request **is** the notification. The "friend requests" inbox is simply:

```ruby
Friendship.pending.where(addressee: current_user)
```

Rendered as a list with Accept / Decline buttons (`PATCH /friendships/:id` → `accept`/`decline`, or member routes). This satisfies "in-app notification" for friend requests with **no `Notification` table at all**. Benefits: no duplicate source of truth, no read/unread sync bugs, no notification lifecycle to maintain.

Optional lightweight polish (defer unless trivial): an unread **count badge** in the nav = `Friendship.pending.where(addressee: current_user).count`. This is a query, still no table.

#### 2c. Why NOT build a generic Notification/inbox now

S-03 will need an in-app inbox for **session confirm/reject** (`prd.md:89-90, 126`; `test-plan.md:49, 58, 61`). It is tempting to build one polymorphic `Notification` model in S-02 and reuse it. Recommendation: **don't**, for these reasons:

- **YAGNI / one consumer**: a generalization built against a single use case usually models the wrong abstraction. Wait for the second real type (session-confirm) so the shared shape is evidence-based.
- **S-02 doesn't need persistence**: friend requests are already queryable state. A `Notification` row would just mirror the `friendships` row and require keeping them in sync.
- **Repo norm**: the codebase defers abstraction on purpose — e.g. "no `ApplicationService` base class until 5+ services share boilerplate" (`app/AGENTS.md:38-42`). Same spirit applies to a notifications framework.

When S-03 arrives, revisit: either (a) a polymorphic `Notification` (`belongs_to :notifiable, polymorphic: true`, `read_at`, recipient) that the friend-request list *also* migrates onto, or (b) keep both inboxes as separate derived queries behind one "inbox" view. Record that decision in S-03's plan; it is explicitly **out of scope for S-02**.

## Code References

- `db/schema.rb:13-53` — current 3-table schema (users, auth sessions, games)
- `app/models/user.rb:1-10` — `User`; `has_many :sessions`; this is where `has_many :friendships` will hang
- `app/models/session.rb:1-12` — **auth** Session (name-collision warning for S-03's game-night model)
- `app/models/game.rb:1-21` — catalog model conventions to mirror
- `config/routes.rb:1-16` — only auth/catalog routes exist; `resources :friendships` to be added
- `db/migrate/20260607120000_create_games.rb:1-19` — migration style to copy
- `app/services/game_catalog/import_service.rb:1-26` — service `.call` convention
- `app/AGENTS.md:24-27, 34-42` — pass `current_user` explicitly; defer abstraction
- `spec/AGENTS.md:14-20` — spec layout (request specs primary; unit vs integration services)

## Architecture Insights

- **Model a "participant" as one join row that is either registered (`user_id`) or guest (`guest_name`)** — this single decision (made in S-03) is what makes guest→user promotion a cheap manual swap and avoids a separate `GuestPlayer` table.
- **Prefer derived state over stored notifications** while there is one notification type; generalize only when S-03 adds the second.
- **Avoid the `Session` name** for the game-night model — it collides with the existing auth `Session`.
- The repo has a strong, consistent "defer abstraction until it pays for itself" culture; both recommendations here follow it.

## Historical Context (from prior changes)

- `context/archive/2026-06-02-minimal-auth-scaffold/` and `context/archive/2026-07-12-email-password-auth/` — establish migration/model/controller/service/spec conventions cited above; phased Intent/Contract plans with automated + manual gates.
- `context/archive/2026-06-07-seed-game-catalog/plan.md:30-34` — canonical pattern references (service `.call`, model validations, migration column order, spec types).
- No archived change discusses friendships, notifications, or guest storage — this is the first.

## Related Research

- None yet. This is the first `research.md` in `context/changes/`. Foundation sources: `prd.md`, `roadmap.md`, `test-plan.md`, `shape-notes.md`.

## Open Questions

1. **Re-request policy after decline** — does a declined request allow re-sending, and after how long? (S-02 `/10x-plan`.)
2. **Keep or delete declined rows** — audit trail vs cleanliness. (Recommend keep; confirm in plan.)
3. **Unread badge in S-02** — include a pending-count badge in nav, or list-only? (Trivial; product call.)
4. **[S-03, not S-02] participant table shape** — confirm the single-table `session_players` with nullable `user_id` + `guest_name` + CHECK constraint when S-03 is planned; that is where the guest-promotion escape hatch is actually reserved.
5. **[S-03] swap re-confirm semantics** — when a guest row is manually swapped to a registered user, does it enter confirm/reject (recommended, per `prd.md:69`)?
6. **[S-03] shared inbox** — whether to introduce a polymorphic `Notification` when the session-confirm inbox lands, and migrate friend requests onto it.
