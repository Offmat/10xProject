# Game Catalog Import Service (F-02) — Plan Brief

> Full plan: `context/changes/seed-game-catalog/plan.md`
> Research: `context/changes/seed-game-catalog/research.md`

## What & Why

Build a reusable operator import service with a Wikidata adapter that seeds the `games` table with ~20 board games for development and S-03 (the north-star session logging slice). The service is designed for reuse — P-03 wraps it with admin UI/auth; P-07 may swap the provider. Without a populated game catalog, S-03's game picker has nothing to select from.

## Starting Point

The codebase is auth-only: `User`/`Session` models, one service (`AuthAuditLogger`), no game domain. No HTTP-calling services exist, no `webmock` gem, no rake tasks, and `db/seeds/` directory is absent. The research validated Wikidata's Action API (`wbgetentities`) as the right endpoint and confirmed `Net::HTTP` suffices.

## Desired End State

Running `bin/rails game_catalog:import` fetches 20 board games from Wikidata and persists them with name, description, player counts, play time, year, and cross-reference IDs. The import is idempotent — re-running updates existing records without duplicates. The `Game` model is ready for S-03's session form to query.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
|----------|--------|-------------------|--------|
| API endpoint | `wbgetentities` (Action API) | One HTTP call for all 20 entities; SPARQL unnecessary for known Q-ids | Research |
| HTTP client | `Net::HTTP` (stdlib) | Zero deps for a dev-only, run-once fetch; third-party gems are stale or overkill | Research |
| Architecture | Direct fetch→DB (no intermediate YAML) | DB is the destination; unique index enforces idempotency regardless | Research |
| Error policy | Persist with nulls + log warnings | Wikidata coverage varies per title; nullable fields allow partial data | Plan |
| Player count validation | Custom `max >= min` when both present | Catches bad Wikidata data while allowing sparse entries | Plan |
| Play time units | Convert minutes + hours; nil for unknown | Covers 99% of cases; unknown units logged as warning | Plan |
| Retry policy | Retry once with backoff, then raise | Handles transient failures without infinite loops; sets pattern for P-03 | Plan |
| Description column | Include (nullable) | Useful for S-03 game picker UI display | Plan |
| Seed list | Concrete 20-game curated list | Eliminates ambiguity; games chosen for Wikidata coverage and popularity | Plan |
| Test infrastructure | WebMock + 5 spec files (including rake task) | First external-API service sets the testing pattern for the project | Plan |

## Scope

**In scope:**
- `Game` model + migration (with description column)
- 3-class service layer: `WikidataClient`, `WikidataMapper`, `ImportService`
- Rake task `game_catalog:import`
- Curated 20-game seed list (`db/seeds/mvp_seed_list.yml`)
- WebMock gem + test infrastructure
- 5 spec files (3 unit + 1 integration + 1 rake task)
- Retry-once resilience on HTTP failures
- Chunking support for >50 IDs (P-03 readiness)

**Out of scope:**
- Admin UI (P-03)
- BGG or alternative provider (P-07)
- Background jobs or scheduled imports
- User-facing game search
- Game images/artwork
- Wiring into `db:seed`

## Architecture / Approach

```
db/seeds/mvp_seed_list.yml      ← hand-curated Q-ids + fallback names
        ↓
GameCatalog::WikidataClient     ← 1× wbgetentities via Net::HTTP (retry once)
        ↓
GameCatalog::WikidataMapper     ← per-entity claim parsing → attribute hashes
        ↓
Game.find_or_initialize_by      ← upsert to DB, idempotent on wikidata_id
```

Three classes in `app/services/game_catalog/`, clear separation: HTTP boundary, data transformation, orchestration + persistence. Provider swap (P-07) replaces Client + Mapper; ImportService stays.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|-----------------|----------|
| 1. Database & Model Foundation | `games` table, `Game` model, webmock gem, test infra | Migration conflicts if other branches touch schema |
| 2. Service Layer | WikidataClient + WikidataMapper + ImportService with unit tests | Wikidata response edge cases not covered by fixtures |
| 3. Orchestration & Integration | Rake task, seed list, integration test, manual import | Q-ids may not all resolve correctly against live API |

**Prerequisites:** F-01 (auth scaffold) is done; PostgreSQL running locally; network access for manual Wikidata verification in Phase 3.
**Estimated effort:** ~2-3 sessions across 3 phases (each phase is independently committable).

## Open Risks & Assumptions

- Q-ids in the seed list are best-effort — some may have changed or been merged on Wikidata since research
- Wikidata entity structure may have edge cases not covered in the 2-3 entity fixture (mitigated by fallback names and nullable fields)
- `webmock` gem version ~> 3.26 assumes compatibility with Ruby 3.4 + Rails 8.1 (high confidence but untested)

## Success Criteria (Summary)

- `bin/rails game_catalog:import` successfully persists ~20 games from Wikidata
- Re-running the import is idempotent (no duplicates)
- `bin/ci` passes with all new specs green and no regressions
