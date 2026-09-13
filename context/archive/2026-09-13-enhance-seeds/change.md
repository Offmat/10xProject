---
change_id: enhance-seeds
title: Enrich seeds with users, friendships, and varied game sessions
status: archived
created: 2026-09-13
updated: 2026-09-13
archived_at: 2026-09-13T15:13:02Z
---

## Notes

Expand `db/seeds.rb` so local/dev data covers the main social and session flows.

### Users

- Seed **4 users**: keep `alice@example.com`, `bob@example.com`, `alex@example.com`, and add a fourth.
- Share one password for all seed users; keep the current value (`Qwertyuiop`), defined as a **named constant** in seeds (not a repeated literal).

### Friendships

- Seed a mix of **accepted** friendships and **pending** friendship requests so both states are easy to exercise in the UI.

### Game sessions (Alice-centric)

- Use **Alice** as the primary demo account.
- Give Alice **multiple game sessions** that cover:
  - sessions with different **signed-in** players
  - sessions that include **guest** players
  - some **solo** sessions
