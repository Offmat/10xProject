# Game Catalog Import Service (F-02) Implementation Plan

## Post-implementation deviation (2026-06-08)

> **Data access switched from Action API (`wbgetentities`) to SPARQL Query Service.** The three-class architecture (WikidataClient → WikidataMapper → ImportService) is preserved, but the HTTP boundary and mapper contracts changed:
>
> - **WikidataClient** now queries `query.wikidata.org/sparql` with a `VALUES` clause instead of `wbgetentities` with chunked IDs. Single request for all QIDs.
> - **WikidataMapper** receives flat SPARQL bindings (array of rows) instead of nested entity JSON. Maps columns directly — no rank sorting, snaktype checks, or claim traversal. Play time unit conversion (hours → minutes) is handled in SPARQL via `BIND(IF(...))`.
> - **ImportService** adapted: client returns bindings array, mapper returns attrs list. Missing entities detected by comparing returned QIDs against seed list.
>
> Motivation: eliminate ~50 lines of brittle JSON traversal (rank ordering, datavalue type checks, unit URI parsing). SPARQL `wdt:` prefix returns truthy values automatically.
>
> See `doubts.md` for accepted risks (D1–D6) and resolutions.

## Overview

Build a reusable operator import service with a Wikidata SPARQL adapter that fetches board game data via the SPARQL Query Service (`query.wikidata.org/sparql`), maps flat result bindings to game attributes, and upserts `Game` records idempotently. The service seeds ~20 titles for development and S-03, uses `Net::HTTP` (stdlib), retries once on failure, and reports results. The same service supports larger imports later (P-03 wraps UI/auth only).

## Current State Analysis

The codebase is at the auth-only stage:
- One service (`AuthAuditLogger`) using class-method pattern
- `User`/`Session` models with validations and normalizations
- No game catalog, no HTTP-calling services, no `webmock` gem
- `lib/tasks/` is empty; `db/seeds/` directory doesn't exist
- Test infrastructure: RSpec 8, FactoryBot, shoulda-matchers — no HTTP stubbing

### Key Discoveries:

- `app/services/auth_audit_logger.rb:1-14` — Service pattern: class method entry point (`.log`), plain Ruby class
- `app/models/user.rb:1-10` — Model pattern: inline `validates`, `normalizes` with lambda
- `db/migrate/20260602150526_create_users.rb` — Migration pattern: domain columns first, `t.timestamps`, indexes outside block
- `spec/services/unit/auth_audit_logger_spec.rb` — Unit spec pattern: `type: :service`, stub collaborators, assert behavior
- `spec/rails_helper.rb:26` — Support auto-loading: `Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }`
- Wikidata API verified live: ~~`wbgetentities` returns up to 50 entities per request~~ switched to SPARQL Query Service; `VALUES` clause handles all QIDs in one request; `wikibase:language "en,mul"` for label fallback

## Desired End State

After this plan is complete:
- `bin/rails game_catalog:import` fetches ~20 games from Wikidata and persists them in the `games` table
- Running the task twice produces the same result (idempotent upsert on `wikidata_id`)
- The `Game` model is available for S-03's session logging game picker
- All specs pass with WebMock stubbing (no real API calls in tests)
- The service layer is structured for future provider swap (P-07) and larger imports (P-03)

### Verification:

```bash
bin/rails game_catalog:import
# => Games: 20 created, 0 updated, 0 skipped

bin/rails game_catalog:import
# => Games: 0 created, 20 updated, 0 skipped

bin/rails runner "puts Game.count"
# => 20

bin/rspec
# => All specs pass (no external API calls)
```

## What We're NOT Doing

- No admin UI for catalog management (P-03)
- No user-facing game search or lookup
- No BGG or alternative provider adapter (P-07)
- No live Wikidata lookup during session logging
- No publisher resolution (requires extra API calls)
- No game images or artwork
- No wiring into `db:seed` — this is an explicit operator task
- No background job or scheduled import

## Implementation Approach

Three-class service layer with clear separation:
1. **WikidataClient** — HTTP boundary (fetch, retry, User-Agent compliance)
2. **WikidataMapper** — Data transformation (claim parsing, unit conversion, label fallback)
3. **ImportService** — Orchestration (read seed list → fetch → map → upsert → report)

A single rake task (`game_catalog:import`) invokes the service. Input is a hand-curated YAML file (`db/seeds/mvp_seed_list.yml`) with Q-ids and fallback names. Output goes directly to the `games` table — no intermediate files.

## Critical Implementation Details

### Timing & lifecycle

The webmock gem must be added and `spec/support/webmock.rb` created in Phase 1 — before any service specs run. The `WebMock.disable_net_connect!` call affects ALL specs globally, so it must be present from the start to catch accidental network calls.

### State sequencing

`ImportService` must call `find_or_initialize_by(wikidata_id:)` then `assign_attributes` then `save!` — not `find_or_create_by` — to ensure re-imports update stale data (e.g. if a Wikidata editor fixes a player count).

---

## Phase 1: Database & Model Foundation

### Overview

Create the `games` table, `Game` model with validations (including player count consistency and description), add `webmock` to the test group, and set up WebMock configuration for the entire test suite.

### Changes Required:

#### 1. Migration

**File**: `db/migrate/YYYYMMDDHHMMSS_create_games.rb`

**Intent**: Create the `games` table with all columns needed by the import service and future S-03 game picker. Include `description` for UI display.

**Contract**: Table `games` with columns: `name` (string, NOT NULL), `wikidata_id` (string, NOT NULL), `description` (string, nullable), `bgg_id` (string, nullable), `min_players` (integer, nullable), `max_players` (integer, nullable), `year_published` (integer, nullable), `play_time_minutes` (integer, nullable), `source` (string, NOT NULL, default `'wikidata'`), `imported_at` (datetime, nullable), `timestamps`. Indexes: unique on `wikidata_id`, non-unique on `bgg_id`.

#### 2. Game Model

**File**: `app/models/game.rb`

**Intent**: ActiveRecord model with validations matching the schema constraints and a custom validation ensuring `max_players >= min_players` when both are present. Normalize `wikidata_id` (strip + upcase).

**Contract**: Validates presence of `name`, `wikidata_id`, `source`. Validates uniqueness of `wikidata_id`. Numericality validations on player counts (> 0), year (integer), play time (> 0) — all `allow_nil: true`. Custom `validate :player_count_consistency` fires only when both `min_players` and `max_players` are present. `normalizes :wikidata_id, with: ->(id) { id.strip.upcase }`.

#### 3. Add webmock gem

**File**: `Gemfile`

**Intent**: Add HTTP stubbing capability for the test suite, required before any service specs exercise the WikidataClient.

**Contract**: `gem 'webmock', '~> 3.26', group: :test` — test group only (not development).

#### 4. WebMock support configuration

**File**: `spec/support/webmock.rb`

**Intent**: Disable all real network connections in specs by default (except localhost for system tests). Auto-loaded by `rails_helper.rb` via the support glob.

**Contract**: `require 'webmock/rspec'` + `WebMock.disable_net_connect!(allow_localhost: true)`.

#### 5. Game factory

**File**: `spec/factories/games.rb`

**Intent**: FactoryBot definition for `Game` following existing factory patterns.

**Contract**: Factory `:game` with `sequence(:name)`, `sequence(:wikidata_id)` generating `Q#{n}` format, `source { 'wikidata' }`.

#### 6. Game model spec

**File**: `spec/models/game_spec.rb`

**Intent**: Validate model behavior: presence validations, uniqueness, normalization, and the custom player count consistency rule.

**Contract**: Uses shoulda-matchers for standard validations. Custom examples for: `wikidata_id` normalization (strip + upcase), player count consistency (valid when max >= min, invalid when max < min, skipped when either is nil).

### Success Criteria:

#### Automated Verification:

- Migration applies cleanly: `bin/rails db:migrate`
- Model spec passes: `bin/rspec spec/models/game_spec.rb`
- Bundle installs without errors: `bundle install`
- All existing specs still pass: `bin/rspec`
- Lint passes: `bin/rubocop`

#### Manual Verification:

- `bin/rails runner "Game.create!(name: 'Test', wikidata_id: 'Q1', source: 'wikidata')"` succeeds
- Duplicate `wikidata_id` raises `ActiveRecord::RecordNotUnique`

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 2: Service Layer

### Overview

Build the three service classes (WikidataClient, WikidataMapper, ImportService) with comprehensive unit tests. Each class has a single responsibility and clear interfaces. Uses WebMock fixtures for all HTTP interactions.

### Changes Required:

#### 1. Wikidata JSON fixtures

**File**: `spec/fixtures/wikidata/wbgetentities_batch.json`

**Intent**: Static JSON fixture representing a real `wbgetentities` response with 2-3 entities covering edge cases: one rich entity (all fields present), one sparse entity (missing player counts and play time), one with `mul` label instead of `en`.

**Contract**: JSON matching the structure documented in research section 3. Must include entities with IDs matching the seed list (at minimum Q36718832 for Terraforming Mars). Include `labels`, `descriptions`, `claims` with properties P2339, P1872, P1873, P577, P2047. Include edge cases: quantity with `+` prefix, time with precision 9, play time in hours (Q11579 unit).

**File**: `spec/fixtures/wikidata/wbgetentities_error.json`

**Intent**: Static JSON fixture representing a Wikidata API error response for error-handling tests.

**Contract**: JSON with `error` key containing `code` and `info` fields (matching real API error format).

#### 2. Wikidata fixture helper

**File**: `spec/support/wikidata_fixtures.rb`

**Intent**: Helper module for loading Wikidata JSON fixtures in specs. Not globally included — specs that need it `include WikidataFixtures` explicitly.

**Contract**: Module with `wikidata_fixture(name)` (returns raw string) and `parsed_wikidata_fixture(name)` (returns parsed JSON). Reads from `spec/fixtures/wikidata/`.

#### 3. WikidataClient

**File**: `app/services/game_catalog/wikidata_client.rb`

**Intent**: HTTP boundary class that fetches entity data from Wikidata's Action API. Handles URL construction, User-Agent header, timeout, response parsing, and retry-once on transient failures (timeout, 5xx).

**Contract**: Class `GameCatalog::WikidataClient` with class method `.fetch(wikidata_ids:)` accepting an array of Q-id strings. Returns parsed JSON hash (the `entities` portion of the response). Raises `GameCatalog::WikidataClient::Error` on non-recoverable failure (after one retry). User-Agent follows Wikimedia format: `all-aBoard/0.1 (contact) Ruby/#{RUBY_VERSION}`. Timeout: 30 seconds. Chunks requests at 50 IDs (for future P-03 compatibility).

#### 4. WikidataClient unit spec

**File**: `spec/services/unit/game_catalog/wikidata_client_spec.rb`

**Intent**: Verify HTTP behavior with WebMock: correct URL/params, User-Agent header, response parsing, retry behavior on timeout/5xx, error raising after retry exhaustion, chunking for >50 IDs.

**Contract**: Uses WebMock `stub_request`. Tests: successful fetch, User-Agent present, retry on timeout then success, retry on 500 then success, raise after second failure, chunking behavior (stub two requests for 51 IDs).

#### 5. WikidataMapper

**File**: `app/services/game_catalog/wikidata_mapper.rb`

**Intent**: Pure data transformation — takes a single Wikidata entity hash and returns an attributes hash suitable for `Game` creation/update. Handles label fallback (en → mul → seed_name), claim extraction with rank preference, quantity parsing (strip `+`), time extraction (year from precision-9 dates), and play time unit conversion (minutes + hours → minutes).

**Contract**: Class `GameCatalog::WikidataMapper` with `.call(entity, seed_name: nil)` returning `{ attrs: Hash, warnings: Array<String> }` where attrs has keys: `wikidata_id`, `name`, `description`, `bgg_id`, `min_players`, `max_players`, `year_published`, `play_time_minutes`, `source`. Collects warnings (unknown play time units, missing labels with no seed_name fallback) in the returned array for ImportService to aggregate. Label fallback chain: en → mul → P373 (Commons category) → seed_name.

#### 6. WikidataMapper unit spec

**File**: `spec/services/unit/game_catalog/wikidata_mapper_spec.rb`

**Intent**: Test all mapping paths: rich entity extraction, label fallback chain (en → mul → seed_name → nil returns nil + logs warning), quantity parsing (strip `+`, to_i), year extraction from time claims, play time conversion (minutes pass-through, hours × 60), unknown unit → nil + warning, rank preference (preferred > normal > deprecated), missing claims → nil.

**Contract**: Uses `parsed_wikidata_fixture('wbgetentities_batch')` for rich/sparse entities. Also tests edge cases with hand-built minimal entity hashes. Includes `WikidataFixtures` module.

#### 7. ImportService

**File**: `app/services/game_catalog/import_service.rb`

**Intent**: Orchestrator that reads the seed list YAML, delegates to WikidataClient for fetching and WikidataMapper for parsing, then upserts Game records. Returns a structured result with counts and warnings.

**Contract**: Class `GameCatalog::ImportService` with `.call(seed_file: Rails.root.join('db/seeds/mvp_seed_list.yml'))` returning `{ created: Integer, updated: Integer, skipped: Integer, warnings: Array<String> }`. Uses `Game.find_or_initialize_by(wikidata_id:)` then `assign_attributes` then `save!`. Sets `imported_at` to `Time.current` on every successful persist. Collects warnings from mapper and any validation failures (logs + increments `skipped` counter instead of raising). When a seed entry's `wikidata_id` is absent from the API response (entity not returned), skips that entry and appends a warning — does not raise.

#### 8. ImportService unit spec

**File**: `spec/services/unit/game_catalog/import_service_spec.rb`

**Intent**: Test orchestration logic with stubbed dependencies (no real HTTP, no real DB). Verify: reads seed list, calls client with correct IDs, calls mapper for each entity, returns correct counts, handles mapper warnings, handles save failures gracefully (skips + warns).

**Contract**: Stubs `GameCatalog::WikidataClient.fetch` and `GameCatalog::WikidataMapper.call`. Uses a temp seed file or stub `YAML.load_file`. Verifies the orchestration flow and result hash.

### Success Criteria:

#### Automated Verification:

- Client spec passes: `bin/rspec spec/services/unit/game_catalog/wikidata_client_spec.rb`
- Mapper spec passes: `bin/rspec spec/services/unit/game_catalog/wikidata_mapper_spec.rb`
- ImportService spec passes: `bin/rspec spec/services/unit/game_catalog/import_service_spec.rb`
- All existing specs still pass: `bin/rspec`
- Lint passes: `bin/rubocop`
- No Brakeman warnings on new files: `bin/brakeman`

#### Manual Verification:

- `bin/rails runner "GameCatalog::WikidataMapper.call({'id' => 'Q1', 'labels' => {'en' => {'value' => 'Test'}}, 'descriptions' => {}, 'claims' => {}})"` returns expected hash in console

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 3: Orchestration & Integration

### Overview

Wire everything together: create the seed list file with 20 curated games, the rake task, the integration test proving idempotent import, and the rake task spec. Run the full import against real Wikidata (manual verification only — specs use WebMock).

### Changes Required:

#### 1. Seed list file

**File**: `db/seeds/mvp_seed_list.yml`

**Intent**: Hand-curated list of ~20 popular board games with Wikidata Q-ids and fallback names. These are well-known titles with good Wikidata coverage, spanning different player counts and complexity levels for realistic development data.

**Contract**: YAML array of hashes, each with `wikidata_id` (string) and `name` (string). Contents:

```yaml
- wikidata_id: Q243519
  name: Catan
- wikidata_id: Q36718832
  name: Terraforming Mars
- wikidata_id: Q580509
  name: Pandemic
- wikidata_id: Q734130
  name: Ticket to Ride
- wikidata_id: Q1478220
  name: 7 Wonders
- wikidata_id: Q223836
  name: Carcassonne
- wikidata_id: Q47305411
  name: Azul
- wikidata_id: Q61893598
  name: Wingspan
- wikidata_id: Q21048498
  name: Codenames
- wikidata_id: Q1238895
  name: Dominion
- wikidata_id: Q16949512
  name: Splendor
- wikidata_id: Q756321
  name: Agricola
- wikidata_id: Q25131291
  name: Scythe
- wikidata_id: Q30069943
  name: Gloomhaven
- wikidata_id: Q40946216
  name: Spirit Island
- wikidata_id: Q55624538
  name: Root
- wikidata_id: Q57756810
  name: Everdell
- wikidata_id: Q1743539
  name: King of Tokyo
- wikidata_id: Q1231249
  name: Dixit
- wikidata_id: Q48994227
  name: Brass Birmingham
```

Note: Q-ids are best-effort from known Wikidata entries. The implementer should verify each ID resolves correctly when running the import — the fallback `name` field ensures games persist even if a Q-id is wrong.

#### 2. Rake task

**File**: `lib/tasks/game_catalog.rake`

**Intent**: Single operator-facing task that invokes ImportService and prints results. Not wired into `db:seed`.

**Contract**: `namespace :game_catalog` with `task import: :environment`. Calls `GameCatalog::ImportService.call`, prints created/updated/skipped counts and any warnings to stdout.

#### 3. Rake task spec

**File**: `spec/tasks/game_catalog_rake_spec.rb`

**Intent**: Verify the rake task exists, loads correctly, and invokes ImportService when called.

**Contract**: Loads rake tasks via `Rails.application.load_tasks`. Stubs `GameCatalog::ImportService.call` to return a result hash. Invokes `Rake::Task['game_catalog:import']`. Verifies ImportService was called. Uses `type: :task` metadata (or no metadata — just `require 'rails_helper'` and rake loading).

#### 4. Integration test

**File**: `spec/services/integration/game_catalog_import_spec.rb`

**Intent**: End-to-end test proving the full flow works: read seed list → fetch (WebMock) → parse → persist → idempotent re-import. Uses real DB, stubbed HTTP.

**Contract**: Includes `WikidataFixtures`. Uses a test-specific seed file (`spec/fixtures/wikidata/test_seed_list.yml`) with 2–3 entries matching the entities in the JSON fixture — passed via `ImportService.call(seed_file:)`. Stubs Wikidata API with WebMock returning `wbgetentities_batch.json`. Tests: first import creates expected number of games with correct attributes, second import updates (no duplicates, same count), `imported_at` is set, `source` is `'wikidata'`.

#### 5. Create db/seeds directory

**File**: `db/seeds/` (directory)

**Intent**: The `db/seeds/` directory doesn't exist — only `db/seeds.rb`. Create it to house the seed list YAML.

**Contract**: Directory `db/seeds/` exists with `mvp_seed_list.yml` inside.

### Success Criteria:

#### Automated Verification:

- Integration test passes: `bin/rspec spec/services/integration/game_catalog_import_spec.rb`
- Rake task spec passes: `bin/rspec spec/tasks/game_catalog_rake_spec.rb`
- Full suite passes: `bin/rspec`
- Lint passes: `bin/rubocop`
- CI checks pass: `bin/ci`

#### Manual Verification:

- Run `bin/rails game_catalog:import` against real Wikidata API — observe ~20 games created
- Run `bin/rails game_catalog:import` again — observe 0 created, ~20 updated
- `bin/rails runner "puts Game.pluck(:name).sort.join(', ')"` shows all 20 game names
- Verify at least one game has all fields populated (name, description, bgg_id, player counts, year, play time)
- Verify a sparse game has nil fields (not empty strings)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Testing Strategy

### Unit Tests:

- **WikidataMapper**: Label fallback chain, quantity parsing (+prefix), year extraction, play time unit conversion (min/hr), rank preference, missing claims → nil, unknown units → warning
- **WikidataClient**: Correct URL construction, User-Agent header, response parsing, retry on timeout, retry on 5xx, raise after retry exhaustion, chunking at 50 IDs
- **ImportService**: Orchestration flow, result counting, warning collection, graceful skip on save failure

### Integration Tests:

- Full import flow: seed list → WebMock fetch → parse → persist
- Idempotent re-import: no duplicates, records updated
- `imported_at` timestamp set on persist

### Rake Task Test:

- Task exists and is invocable
- Calls ImportService.call
- Outputs result counts

### Manual Testing Steps:

1. Run `bin/rails game_catalog:import` in development (real Wikidata call)
2. Verify ~20 games persisted with `Game.count`
3. Inspect a rich game: `Game.find_by(wikidata_id: 'Q36718832').attributes`
4. Inspect a sparse game for nil handling
5. Re-run import — verify no duplicates
6. Run `bin/ci` — all quality gates pass

## Performance Considerations

- Single HTTP call for 20 entities (Wikidata allows 50 per request) — no performance concern for MVP
- Future P-03 imports: chunking at 50 IDs + 1-second sleep between chunks provides rate courtesy
- No background job needed — operator-initiated, runs in seconds
- Unique index on `wikidata_id` ensures fast upsert lookups

## Migration Notes

- The `games` table is new — no data migration needed
- Running `bin/rails db:migrate` adds the table
- Existing `db:seed` is unaffected (import is a separate rake task)
- Test DB needs `bin/rails db:test:prepare` after migration

## References

- Research: `context/changes/seed-game-catalog/research.md`
- Service pattern: `app/services/auth_audit_logger.rb`
- Model pattern: `app/models/user.rb`
- Migration pattern: `db/migrate/20260602150526_create_users.rb`
- Unit spec pattern: `spec/services/unit/auth_audit_logger_spec.rb`
- Factory pattern: `spec/factories/users.rb`
- Spec conventions: `spec/AGENTS.md`
- Wikidata SPARQL docs: `https://www.wikidata.org/wiki/Wikidata:SPARQL_tutorial`
- Wikidata WikiProject Board Games: `https://www.wikidata.org/wiki/Wikidata:WikiProject_Board_Games`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Database & Model Foundation

#### Automated

- [x] 1.1 Migration applies cleanly: `bin/rails db:migrate` — 822df41
- [x] 1.2 Model spec passes: `bin/rspec spec/models/game_spec.rb` — 822df41
- [x] 1.3 Bundle installs without errors: `bundle install` — 822df41
- [x] 1.4 All existing specs still pass: `bin/rspec` — 822df41
- [x] 1.5 Lint passes: `bin/rubocop` — 822df41

#### Manual

- [x] 1.6 Game.create! with valid attrs succeeds in console — 822df41
- [x] 1.7 Duplicate wikidata_id raises RecordNotUnique — 822df41

### Phase 2: Service Layer

#### Automated

- [x] 2.1 Client spec passes: `bin/rspec spec/services/unit/game_catalog/wikidata_client_spec.rb` — 822df41
- [x] 2.2 Mapper spec passes: `bin/rspec spec/services/unit/game_catalog/wikidata_mapper_spec.rb` — 822df41
- [x] 2.3 ImportService spec passes: `bin/rspec spec/services/unit/game_catalog/import_service_spec.rb` — 822df41
- [x] 2.4 All existing specs still pass: `bin/rspec` — 822df41
- [x] 2.5 Lint passes: `bin/rubocop` — 822df41
- [x] 2.6 No Brakeman warnings: `bin/brakeman` — 822df41

#### Manual

- [x] 2.7 WikidataMapper.call with minimal entity hash returns expected result in console — 822df41

### Phase 3: Orchestration & Integration

#### Automated

- [x] 3.1 Integration test passes: `bin/rspec spec/services/integration/game_catalog_import_spec.rb` — 822df41
- [x] 3.2 Rake task spec passes: `bin/rspec spec/tasks/game_catalog_rake_spec.rb` — 822df41
- [x] 3.3 Full suite passes: `bin/rspec` — 822df41
- [x] 3.4 Lint passes: `bin/rubocop` — 822df41
- [x] 3.5 CI checks pass: `bin/ci` — 822df41

#### Manual

- [x] 3.6 `bin/rails game_catalog:import` creates ~20 games from real Wikidata — 822df41
- [x] 3.7 Re-run produces 0 created, ~20 updated (idempotent) — 822df41
- [x] 3.8 Rich game has all fields populated; sparse game has nils — 822df41
