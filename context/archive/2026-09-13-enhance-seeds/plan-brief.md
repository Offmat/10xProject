# Enrich Seeds — Plan Brief

> Full plan: `context/changes/enhance-seeds/plan.md`

## What & Why

Local `db:seed` should give a ready demo of the social + session product surface: four logins, accepted and pending friendships, and Alice-owned sessions that mix friends, guests, and solo play — without hand-crafting records in the console after every reset.

## Starting Point

Seeds today upsert three users (shared password string) and ~20 games from YAML. Friendships and game sessions are not seeded; production create paths already exist (`Friendship` rows; `GameSessions::Create`).

## Desired End State

After seed: alice/bob/alex/carol share `Qwertyuiop`; Alice is friends with Bob and Alex; Carol has a pending request to Alice; Alice has a small, varied session history with most friend tags confirmed and one left pending for the confirm UX. Re-running seed wipes and recreates that demo graph.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) |
| -------- | ------ | ---------------- |
| Fourth user | `carol@example.com` | Matches existing `@example.com` naming |
| Friendship graph | Alice hub: accepted with Bob/Alex; pending Carol→Alice | Unlocks Alice multi-friend sessions + pending UI |
| Friend participant status | Mixed: confirm most; leave one pending | Demos history visibility and confirm flow |
| Re-seed strategy | Wipe-and-recreate friendships + Alice sessions | Deterministic; simpler than fingerprinting sessions |
| Verification | Manual seed checklist only | LOW scope; no CI surface for demo data |
| Password | Keep `Qwertyuiop` as a named constant | Unchanged value; stop repeating the literal |

## Scope

**In scope:** `db/seeds.rb` (+ optional thin `db/seeds/` helpers); users; friendships; Alice sessions via Create + selective confirm.

**Out of scope:** password value change; schema; factories in seeds; automated seed specs; non-Alice creators; games YAML / Wikidata changes.

## Architecture / Approach

Upsert users/games → wipe Alice-created sessions and friendships among seed users → recreate friendship graph → `GameSessions::Create` for the inventory → `confirm!` all but one friend participation.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Users & friendships | Constant + Carol + Alice-hub graph | Wipe scope too broad/narrow |
| 2. Alice game sessions | Solo/guest/friend inventory + mixed confirm | Create fails if friendships/order wrong |

**Prerequisites:** Postgres up; games YAML still loadable (existing seed).
**Estimated effort:** ~1 short session across 2 phases.

## Open Risks & Assumptions

- Wipe deletes any local Alice-created sessions on seed (intentional).
- Guest display names should not collide with Carol the user.
- Seed helpers may live inline or under `db/seeds/` — implementer’s call for readability.

## Success Criteria (Summary)

- Double `db:seed` stays deterministic and exits 0
- Alice can exercise friends, pending request, and varied sessions in the UI
- One pending friend confirm remains for demo
