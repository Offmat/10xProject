---
project: all-aBoard
version: 1
created: 2026-06-01
updated: 2026-06-07
system: github-issues
roadmap_version: 1
---

# Backlog: all-aBoard

> Execution backlog lives on GitHub. **Sequencing and dependencies** stay in @context/foundation/roadmap.md — this file is the map to where work is tracked.

## System

| Item | Value |
|---|---|
| Repository | [Offmat/10xProject](https://github.com/Offmat/10xProject) |
| Project board | [all-aBoard Roadmap](https://github.com/users/Offmat/projects/2) |
| Milestone (MVP) | [MVP v1](https://github.com/Offmat/10xProject/milestone/1) |
| Tooling | GitHub Issues + GitHub Projects v2 |

Each roadmap item has a structured issue body (Outcome, Change ID, PRD refs, Risk, Dependencies) so `/10x-plan <change-id>` can start without re-reading the full roadmap.

## Active issues (MVP v1)

Dependency order — pick the first row whose blockers are closed.

| Roadmap ID | Change ID | Issue | Ready for `/10x-plan` | Blocked by |
|---|---|---|---|---|
| F-01 | minimal-auth-scaffold | [#6](https://github.com/Offmat/10xProject/issues/6) | — | — |
| F-02 | seed-game-catalog | [#7](https://github.com/Offmat/10xProject/issues/7) | yes | — |
| S-01 | email-password-auth | [#8](https://github.com/Offmat/10xProject/issues/8) | yes | — |
| S-02 | mutual-friend-circle | [#9](https://github.com/Offmat/10xProject/issues/9) | no | #8 |
| S-03 | log-session-with-confirm | [#10](https://github.com/Offmat/10xProject/issues/10) | no | #9, #7 |
| S-04 | session-stats-filters | [#11](https://github.com/Offmat/10xProject/issues/11) | no | #10 |

**Start here:** [#6 — Scaffold email/password auth](https://github.com/Offmat/10xProject/issues/6) → `/10x-plan minimal-auth-scaffold`

## Parked issues

Deferred scope from roadmap `## Parked`. Not in MVP v1 milestone; project board Status is Done.

| Parked ID | Change ID | Issue |
|---|---|---|
| P-01 | recommended-games-list | [#12](https://github.com/Offmat/10xProject/issues/12) |
| P-02 | per-game-ratings | [#13](https://github.com/Offmat/10xProject/issues/13) |
| P-03 | admin-catalog-curation | [#14](https://github.com/Offmat/10xProject/issues/14) |
| P-04 | push-notifications | [#15](https://github.com/Offmat/10xProject/issues/15) |
| P-05 | external-game-database | [#16](https://github.com/Offmat/10xProject/issues/16) |
| P-06 | team-workspaces | [#17](https://github.com/Offmat/10xProject/issues/17) |
| P-07 | catalog-provider-switch | — |

## Labels

| Label | Used for |
|---|---|
| `roadmap` | All items derived from roadmap.md |
| `foundation` | F-01, F-02 |
| `slice` | S-01 … S-04 |
| `parked` | P-01 … P-07 |
| `north-star` | S-03 only |
| `ready` | F-01 (roadmap status `ready`) |
| `stream-a` | MVP path chain |
| `stream-b` | Catalog import (F-02) |
| `wontfix` | Parked / PRD non-goals |

## Project board fields

Custom fields on **all-aBoard Roadmap**: Roadmap ID, Change ID, Stream (A / B / Parked), Type (foundation / slice / parked), Ready for plan (yes / no).

Built-in **Status**: Todo for active MVP items; Done for parked items.

## History

- **2026-06-01** — Migrated 6 active + 6 parked roadmap items to GitHub Issues via `gh` CLI. Source: @context/foundation/roadmap.md (v1).
- **2026-06-05** — F-02 reframed: import service + console invocation (roadmap v1 edit-in-place). F-01 done; F-02 and S-01 unblocked.
- **2026-06-05** — F-02 clarified: catalog import fetches from external game database API (e.g. BGG), not bundled data file; user-facing live lookup remains parked (P-05).
- **2026-06-07** — F-02 catalog provider set to Wikidata for MVP; BGG/provider switch parked as P-07 (`catalog-provider-switch`); no GitHub issue yet.
