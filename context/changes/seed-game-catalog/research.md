---
date: 2026-06-07T15:30:00+02:00
researcher: AI (Cursor Agent)
git_commit: 01c7e3e
branch: main
repository: 10xProject (all-aBoard)
topic: "How to implement seed-game-catalog (F-02): service to fetch, parse, and save game catalog items"
tags: [research, codebase, game-catalog, wikidata, import-service, f-02]
status: complete
last_updated: 2026-06-07
last_updated_by: AI (Cursor Agent)
last_updated_note: "Simplified to direct fetch→DB architecture; removed intermediate YAML phase"
---

# Research: Implementing seed-game-catalog (F-02)

**Date**: 2026-06-07T15:30:00+02:00
**Researcher**: AI (Cursor Agent)
**Git Commit**: 01c7e3e
**Branch**: main
**Repository**: 10xProject (all-aBoard)

## Research Question

How to properly implement the `seed-game-catalog` change (F-02) — a working service to fetch board game data from Wikidata, parse it, and persist `Game` records. The seed file is created once during development and stored in `db/seeds/`. The import service is not called during every `db:seed`.

## Summary

1. **Wikidata Action API** (`wbgetentities`) is the right endpoint — one HTTP call fetches all ~20 entities by Q-id (limit: 50 per request). SPARQL is unnecessary for known Q-ids and has label resolution issues.

2. **No gem needed** — `Net::HTTP` + `JSON` (stdlib) suffice for a one-time dev-only fetch. The `wikidata` gem on RubyGems is stale (0.0.3, 2014); the modern GitHub version is unpublished and overkill.

3. **Direct fetch→DB architecture:** A single rake task reads the hand-curated Q-id list (`db/seeds/mvp_seed_list.yml`), fetches from Wikidata, parses via mapper, and upserts `Game` records directly. No intermediate YAML output file — the DB is the destination.

4. **`Game` model** should mirror existing patterns (`User`-style validations, `normalizes`, unique index on `wikidata_id`). Minimum columns: `name`, `wikidata_id`, `bgg_id`, `min_players`, `max_players`, `year_published`, `play_time_minutes`, `source`.

5. **Testing:** Add `webmock` gem. Unit-test the mapper with fixture JSON files. Unit-test the client with WebMock stubs. Integration-test the full import with WebMock + real DB for upsert idempotency.

## Detailed Findings

### 1. Wikidata API: Action API wins over SPARQL

For ~20 known Q-ids, `wbgetentities` is simpler and more reliable than SPARQL.

| Criterion | Action API `wbgetentities` | SPARQL |
|-----------|---------------------------|--------|
| HTTP calls for 20 ids | **1** (max 50 ids/request) | **1** |
| Label fallback (en→mul→P373) | Straightforward in Ruby mapper | Needs `COALESCE` + extra `OPTIONAL` blocks |
| Multi-valued properties | All statements in `claims`; pick in mapper | Row multiplication unless aggregated |
| Infrastructure | Same cluster as entity storage | Separate Query Service; can be slower |
| Best for | **Known Q-ids, small batches** | Discovery, joins, bulk export |

**Verified live** (2026-06-07): Batch call with `ids=Q36718832|Q223836` returned both entities in one response. The 50-id limit triggers a clear `toomanyvalues` error — split into chunks only if importing >50.

**Critical finding — labels:** Terraforming Mars has no `en` label; the name is in `labels.mul`. Always request `languages=en|mul` and fall back in the mapper.

**API call pattern:**

```http
GET https://www.wikidata.org/w/api.php
  ?action=wbgetentities
  &ids=Q36718832|Q…|Q…     # pipe-separated, max 50
  &props=labels|descriptions|claims
  &languages=en|mul          # mul is essential for fallback
  &format=json
```

### 2. HTTP Client: Net::HTTP is sufficient

The Gemfile has no HTTP client gems (no Faraday, HTTParty, etc.). For a dev-only, run-once import, adding a dependency is not justified.

| Approach | Verdict |
|----------|---------|
| `Net::HTTP` + `JSON` (stdlib) | **Best** — zero deps, ~30 lines, trivial timeout/User-Agent config |
| `wilg/wikidata` (GitHub, not RubyGems) | Reasonable if reusing periodically; adds Faraday + transitive deps |
| `wikidata` (RubyGems 0.0.3) | **Avoid** — stale 2014 code |
| `wikidata_adaptor` (1.0.0) | Wrong tool — REST API, one call per item (20 calls vs 1) |

**Wikimedia User-Agent requirement:** Requests without a descriptive User-Agent may be blocked. Format:

```
all-aBoard/0.1 (https://github.com/<org>/10xProject; contact@example.com) Ruby/3.4.4
```

**Rate limits:** With a compliant User-Agent, limit is 200 req/min. For 1 request, this is trivially safe.

### 3. Response Structure and Mapper Design

**Verified JSON structure** for `wbgetentities` (Terraforming Mars Q36718832):

| Field | Property | `datavalue.type` | Extraction |
|-------|----------|-------------------|------------|
| `name` | labels | — | `labels.en.value ∥ labels.mul.value ∥ P373 ∥ seed_name` |
| `bgg_id` | P2339 | `string` | `value` directly → `"167791"` |
| `min_players` | P1872 | `quantity` | `value.amount` → `"+1"` → strip `+`, `.to_i` |
| `max_players` | P1873 | `quantity` | `value.amount` → `"+5"` → strip `+`, `.to_i` |
| `year_published` | P577 | `time` | `value.time` → `"+2016-00-00T00:00:00Z"` → extract `YYYY` |
| `play_time_minutes` | P2047 | `quantity` | `amount: "+120"`, `unit: ".../Q7727"` (minute) |

**Gotchas documented from live API:**

- Claims are **arrays of statements** — use rank preference (`preferred` > `normal` > `deprecated`) and take first truthy (`snaktype == 'value'`).
- Quantity amounts always have `+` prefix: `"+5"`, not `5`.
- P2047 units vary: usually minutes (Q7727), sometimes hours (Q11579) — check the `unit` URI.
- P577 `precision: 9` means year only; the `00-00` month/day is normal.
- P123 (publisher) returns entity IDs, not names — resolving requires extra API calls. Skip for MVP.

**Mapper class sketch:**

```ruby
module GameCatalog
  class WikidataMapper
    def self.call(entity, seed_name: nil)
      {
        wikidata_id: entity['id'],
        name: display_name(entity, seed_fallback: seed_name),
        bgg_id: first_string_claim(entity, 'P2339'),
        min_players: quantity_claim(entity, 'P1872'),
        max_players: quantity_claim(entity, 'P1873'),
        year_published: time_claim_year(entity, 'P577'),
        play_time_minutes: duration_claim_minutes(entity, 'P2047'),
        source: 'wikidata'
      }
    end
  end
end
```

### 4. Architecture: Direct Fetch→DB Flow

The seed input file (`db/seeds/mvp_seed_list.yml`) is hand-curated with Q-ids and fallback names. A single rake task reads it, fetches from Wikidata, parses, and upserts directly into the `games` table. No intermediate YAML output — the DB is the destination.

```
db/seeds/mvp_seed_list.yml      # hand-curated Q-ids + fallback names (INPUT)
        ↓
GameCatalog::WikidataClient     # 1× wbgetentities via Net::HTTP
        ↓
GameCatalog::WikidataMapper     # per-entity claim parsing → attribute hashes
        ↓
Game.find_or_initialize_by      # upsert directly to DB, idempotent on wikidata_id
```

**Invocation:**

```ruby
# Run once during development (not wired into db:seed)
bin/rails game_catalog:import
```

**Service layer:**

| Class | Responsibility | Location |
|-------|----------------|----------|
| `GameCatalog::WikidataClient` | HTTP fetch from Wikidata API | `app/services/game_catalog/wikidata_client.rb` |
| `GameCatalog::WikidataMapper` | Parse entity JSON → attribute hash | `app/services/game_catalog/wikidata_mapper.rb` |
| `GameCatalog::ImportService` | Orchestrate: read seed list → fetch → map → upsert | `app/services/game_catalog/import_service.rb` |

Three classes, clear separation: HTTP boundary (`WikidataClient`), data transformation (`WikidataMapper`), and orchestration + persistence (`ImportService`).

### 5. Game Model and Migration

**Follow existing patterns** from `User` model (validations, normalizes, unique index).

**Suggested `games` table:**

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_games.rb
class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :name, null: false
      t.string :wikidata_id, null: false
      t.string :bgg_id
      t.integer :min_players
      t.integer :max_players
      t.integer :year_published
      t.integer :play_time_minutes
      t.string :source, null: false, default: 'wikidata'
      t.datetime :imported_at

      t.timestamps
    end
    add_index :games, :wikidata_id, unique: true
    add_index :games, :bgg_id
  end
end
```

**Model:**

```ruby
# app/models/game.rb
class Game < ApplicationRecord
  validates :name, presence: true
  validates :wikidata_id, presence: true, uniqueness: true
  validates :min_players, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :max_players, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :year_published, numericality: { only_integer: true }, allow_nil: true
  validates :play_time_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :source, presence: true

  normalizes :wikidata_id, with: ->(id) { id.strip.upcase }
end
```

**Design decisions:**

- `name` and `wikidata_id` are NOT NULL — every game must have an identifier and display name.
- `bgg_id` indexed but nullable — not all Wikidata entries have a BGG cross-reference.
- Player counts, year, play time are nullable integers — Wikidata coverage varies per title.
- `source` defaults to `'wikidata'` — supports P-07 future provider switch.
- `imported_at` records when the Wikidata fetch ran — distinct from `created_at` (row creation) and `updated_at` (any attribute change). Useful for auditing which import batch a record came from.
- Unique index on `wikidata_id` enforces idempotency at DB level.

### 6. Seed Input File Format

**`db/seeds/mvp_seed_list.yml`** (hand-curated, ~20 entries):

```yaml
- wikidata_id: Q36718832
  name: Terraforming Mars
- wikidata_id: Q243519
  name: Catan
- wikidata_id: Q580509
  name: Pandemic
# ... ~17 more entries
```

Each entry has a stable `wikidata_id` and a `name` fallback for when Wikidata labels are missing or wrong. This is the only seed file — no intermediate output YAML. The `ImportService` reads this, fetches data from Wikidata, and writes directly to the `games` table.

### 7. Rake Task

**Location:** `lib/tasks/game_catalog.rake` (first custom rake file in the project).

```ruby
namespace :game_catalog do
  desc 'Import games from Wikidata using db/seeds/mvp_seed_list.yml'
  task import: :environment do
    result = GameCatalog::ImportService.call
    puts "Games: #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped"
    result[:warnings].each { |w| puts "  WARN: #{w}" } if result[:warnings].any?
  end
end
```

Single task, single command: `bin/rails game_catalog:import`. Not wired into `db:seed`.

### 8. Testing Strategy

**Add `webmock` to Gemfile:**

```ruby
gem 'webmock', '~> 3.26', group: :test
```

No VCR needed — WebMock + static JSON fixtures are sufficient for a predictable, small-batch API.

**Fixture layout:**

```
spec/fixtures/wikidata/
  wbgetentities_batch.json          # response with 2-3 entities (rich + sparse)
  wbgetentities_error.json          # API error payload
```

**Test split (following `spec/AGENTS.md` conventions):**

| Layer | Spec location | HTTP | DB | What to assert |
|-------|---------------|------|----|----------------|
| WikidataMapper | `spec/services/unit/game_catalog/wikidata_mapper_spec.rb` | No | No | Parsed attrs from fixture JSON: name fallback, player counts, year, edge cases |
| WikidataClient | `spec/services/unit/game_catalog/wikidata_client_spec.rb` | **WebMock** | No | Correct URL/query, User-Agent header, response parsing, error handling |
| ImportService | `spec/services/unit/game_catalog/import_service_spec.rb` | No (stub client) | No | Orchestration: reads seed list, calls client + mapper, returns counts |
| Full import | `spec/services/integration/game_catalog_import_spec.rb` | **WebMock** | **Yes** | End-to-end: fetch → parse → persist, idempotent re-import, no duplicates |

**WebMock configuration:**

```ruby
# spec/support/webmock.rb (auto-loaded by rails_helper.rb)
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)
```

**Fixture helper:**

```ruby
# spec/support/wikidata_fixtures.rb
module WikidataFixtures
  def wikidata_fixture(name)
    File.read(Rails.root.join('spec', 'fixtures', 'wikidata', "#{name}.json"))
  end

  def parsed_wikidata_fixture(name)
    JSON.parse(wikidata_fixture(name))
  end
end

# No global include — specs that need it include explicitly:
#   include WikidataFixtures
```

**Mapper unit test example:**

```ruby
RSpec.describe GameCatalog::WikidataMapper, type: :service do
  describe '.call' do
    let(:entities) { parsed_wikidata_fixture('wbgetentities_batch') }

    it 'extracts all fields from a rich entity' do
      entity = entities.dig('entities', 'Q36718832')
      result = described_class.call(entity)

      expect(result).to include(
        wikidata_id: 'Q36718832',
        name: 'Terraforming Mars',
        bgg_id: '167791',
        min_players: 1,
        max_players: 5,
        year_published: 2016,
        play_time_minutes: 120
      )
    end

    it 'falls back to mul label when en is missing' do
      entity = entities.dig('entities', 'Q36718832')
      result = described_class.call(entity)
      expect(result[:name]).to eq('Terraforming Mars')
    end

    it 'uses seed_name fallback when all labels are missing' do
      entity = { 'id' => 'Q999', 'labels' => {}, 'claims' => {} }
      result = described_class.call(entity, seed_name: 'Mystery Game')
      expect(result[:name]).to eq('Mystery Game')
    end
  end
end
```

**Integration test — idempotent import:**

```ruby
RSpec.describe 'Game catalog import', type: :service do
  include WikidataFixtures

  before do
    stub_request(:get, %r{\Ahttps://www\.wikidata\.org/w/api\.php\z})
      .with(query: hash_including('action' => 'wbgetentities'))
      .to_return(status: 200, body: wikidata_fixture('wbgetentities_batch'),
                 headers: { 'Content-Type' => 'application/json' })
  end

  it 'creates games on first import and does not duplicate on second' do
    GameCatalog::ImportService.call
    first_count = Game.count

    GameCatalog::ImportService.call
    expect(Game.count).to eq(first_count)
  end
end
```

**Factory:**

```ruby
# spec/factories/games.rb
FactoryBot.define do
  factory :game do
    sequence(:name) { |n| "Board Game #{n}" }
    sequence(:wikidata_id) { |n| "Q#{100_000 + n}" }
    source { 'wikidata' }
  end
end
```

### 9. Codebase Patterns to Follow

Based on analysis of the existing codebase:

| Concern | Existing pattern | Apply to F-02 |
|---------|------------------|---------------|
| Service API | Class method entry point (`AuthAuditLogger.log`) | `GameCatalog::SeedGenerator.call`, `SeedLoader.call` |
| Service location | `app/services/` | `app/services/game_catalog/` (namespaced module) |
| Model validations | Inline `validates` with options hashes (`User`) | Same style for `Game` |
| Normalization | `normalizes :email, with: ->` | `normalizes :wikidata_id, with: ->` |
| Unique index | `add_index :users, :email, unique: true` | `add_index :games, :wikidata_id, unique: true` |
| Migration style | Domain columns first, then `t.timestamps`, indexes outside block | Same |
| Factory style | `sequence` for unique attrs, single-quoted strings | Same |
| Unit spec metadata | `type: :service`, `describe '.method_name'` | Same |
| Message expectations | `expect(Collaborator).to receive(:method)` before action | Same for adapter stubs |
| Spec layout | `spec/services/unit/` for stubs, `spec/services/integration/` for DB | Same |

## Architecture Insights

### Provider adapter pattern (P-07 future-proofing)

The service layer naturally supports a provider switch later:

```
GameCatalog::WikidataClient   → GameCatalog::BggClient   (future P-07)
GameCatalog::WikidataMapper   → GameCatalog::BggMapper   (future P-07)
```

Both produce the same attribute hash consumed by `SeedGenerator` and `SeedLoader`. The `source` column on `Game` tracks provenance.

### Why direct fetch→DB instead of intermediate YAML?

The initial investigation sketched a reusable import service. An intermediate YAML output file would let other developers seed without Wikidata access, but for ~20 games loaded once during development, it adds unnecessary complexity (extra class, extra file, extra rake task). The DB is the destination — `Game` records with `wikidata_id` uniqueness enforce idempotency regardless.

### Directory structure (new files)

```
app/
  models/
    game.rb
  services/
    game_catalog/
      wikidata_client.rb
      wikidata_mapper.rb
      import_service.rb
db/
  migrate/
    YYYYMMDDHHMMSS_create_games.rb
  seeds/
    mvp_seed_list.yml        # input: hand-curated Q-ids + fallback names
lib/
  tasks/
    game_catalog.rake
spec/
  factories/
    games.rb
  fixtures/
    wikidata/
      wbgetentities_batch.json
      wbgetentities_error.json
  models/
    game_spec.rb
  services/
    unit/
      game_catalog/
        wikidata_mapper_spec.rb
        wikidata_client_spec.rb
        import_service_spec.rb
    integration/
      game_catalog_import_spec.rb
  support/
    webmock.rb
    wikidata_fixtures.rb
```

## Historical Context

- `context/archive/2026-06-02-minimal-auth-scaffold/plan.md` — F-01 plan establishes the phased implementation pattern (scaffold → harden → test harness) and progress tracking convention used in this project.
- `context/changes/seed-game-catalog/initial_investigation.md` — Prior research on Wikidata API, properties, and Ruby gems. This research validates and extends those findings with live API verification and architectural decisions adjusted for the "seed file created once" requirement.

## Code References

- `app/services/auth_audit_logger.rb` — Only existing service; class method pattern to follow
- `app/models/user.rb:1-10` — Model validation/normalization pattern for `Game`
- `db/migrate/20260602150526_create_users.rb:3-10` — Migration structure pattern
- `spec/services/unit/auth_audit_logger_spec.rb` — Unit service spec pattern
- `spec/factories/users.rb` — Factory pattern to follow for `games.rb`
- `spec/AGENTS.md:9` — "Do not commit examples that depend on real external APIs"
- `spec/AGENTS.md:18-19` — Unit vs integration spec directory split

## Open Questions

1. **MVP seed list contents** — The ~20 Q-ids need to be curated. The implementation plan should include a concrete list or defer it to a data task.
2. **Error policy for missing fields** — When a Wikidata entity lacks `min_players` or `year_published`, should the import log a warning and persist with nulls, or skip the entry? Recommendation: persist with nulls + log warnings (player counts are optional in the schema).
3. **Custom validation on player count range** — Should `max_players >= min_players` be a model validation? Recommendation: yes, but only when both are present (`validate :player_count_consistency, if: -> { min_players.present? && max_players.present? }`).
4. **Play time unit handling** — P2047 unit is usually minutes (Q7727) but can be hours (Q11579). The mapper should convert hours to minutes. What about other units? Recommendation: handle minutes + hours, log unknown units.
