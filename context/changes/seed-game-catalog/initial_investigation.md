# Initial investigation: Wikidata for game catalog import

Research for F-02 (`seed-game-catalog`). Focus: how to fetch board-game metadata from Wikidata and practical implementation notes for a reusable Rails import service.

Foundation scope reminder (not the subject of this doc): MVP seeds ~20 titles via console; import service accepts parameterized batches; see `change.md` and `context/foundation/prd.md` for product constraints.

---

## Wikidata basics

- **License:** Structured data in Wikidata main/property namespaces is [CC0](https://www.wikidata.org/wiki/Wikidata:Licensing) (public-domain equivalent). No provider registration or commercial-license gate for read-only import.
- **Board games project:** [WikiProject Board Games](https://www.wikidata.org/wiki/Wikidata:WikiProject_Board_Games) documents common properties and maintenance queries.
- **Endpoints:**
  - Action API (search + entity fetch): `https://www.wikidata.org/w/api.php`
  - SPARQL: `https://query.wikidata.org/sparql`
  - Entity pages: `https://www.wikidata.org/wiki/Q…`

---

## Useful properties for `Game` records

| Property | ID | Use in all-aBoard |
|----------|-----|-------------------|
| instance of | P31 | Filter to board game (Q131436) when searching |
| BoardGameGeek ID | P2339 | Optional cross-ref / lookup key (not a license to copy BGG data) |
| minimum / maximum players | P1872 / P1873 | `min_players`, `max_players` |
| publication date | P577 | `year_published` |
| duration | P2047 | `play_time_minutes` (often in minutes) |
| developer / publisher | P178 / P123 | Optional metadata; multiple publishers common (regional editions) |
| official website | P856 | Optional URL |
| Commons category | P373 | Often holds human-readable name when `label` is missing |
| minimum age | P2899 | Optional |
| genre | P136 | Often imprecise vs hobby taxonomy |

**Idempotency:** Prefer `wikidata_id` (Q-number) as the primary external key. Store `bgg_id` from P2339 when present for future cross-provider work (P-07), but do not treat it as permission to pull BGG API data.

---

## Fetch patterns (simplest first)

### 1. Action API — two HTTP calls (no SPARQL)

Best when you already know a Wikidata Q-id or need a quick search.

```http
GET https://www.wikidata.org/w/api.php
  ?action=wbsearchentities
  &search=Terraforming+Mars
  &language=en
  &format=json

GET https://www.wikidata.org/w/api.php
  ?action=wbgetentities
  &ids=Q36718832
  &props=labels|descriptions|claims
  &languages=en
  &format=json
```

Claims arrive nested (statements, qualifiers, references). You need a mapper to flatten into app fields.

### 2. SPARQL — one query per batch

Good for bulk fetch when seed list is Q-ids or BGG ids.

**By BGG id** (reliable when seed list uses BGG ids from a curated YAML):

```sparql
SELECT ?item ?itemLabel ?bggId ?minPlayers ?maxPlayers ?pubYear ?playTimeMin ?officialUrl ?publisherLabel WHERE {
  ?item wdt:P2339 "167791" .
  OPTIONAL { ?item wdt:P1872 ?minPlayers . }
  OPTIONAL { ?item wdt:P1873 ?maxPlayers . }
  OPTIONAL { ?item wdt:P577 ?pubDate . BIND(YEAR(?pubDate) AS ?pubYear) }
  OPTIONAL { ?item wdt:P2047 ?playTime . BIND(xsd:integer(?playTime) AS ?playTimeMin) }
  OPTIONAL { ?item wdt:P856 ?officialUrl . }
  OPTIONAL { ?item wdt:P123 ?publisher . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
```

**Batch multiple Q-ids:**

```sparql
VALUES ?item { wd:Q36718832 wd:Q… }
# … same OPTIONAL blocks
```

Export formats: JSON (`format=json` on query URL), CSV, TSV via [Wikidata Query Service](https://query.wikidata.org/).

### 3. Wikibase REST API

Documented at [Wikibase REST API](https://doc.wikimedia.org/Wikibase/master/js/rest-api/). Ruby wrappers: `wikidata_adaptor`, `wikidatum` (see gems below).

---

## Live example: Terraforming Mars

- **Entity:** [Q36718832](https://www.wikidata.org/wiki/Q36718832)
- **Description (en):** 2016 board game
- **Label:** multilingual `mul` label "Terraforming Mars" (English `label` may be empty — handle fallbacks)

**Normalized fields (from SPARQL + entity API, 2026-06-07):**

```json
{
  "wikidata_id": "Q36718832",
  "name": "Terraforming Mars",
  "bgg_id": "167791",
  "min_players": 1,
  "max_players": 5,
  "year_published": 2016,
  "play_time_minutes": 120,
  "official_url": "https://fryxgames.se/product/terraforming-mars/",
  "publishers": [
    "FryxGames", "Lautapelit.fi", "MINDOK", "Arclight", "Ghenos Games",
    "Korea Boardgames", "Lavka Games"
  ],
  "genre": "card game",
  "minimum_age": 12,
  "commons_category": "Terraforming Mars"
}
```

**Session-log MVP needs:** `name`, `min_players`, `max_players`, `year_published` (+ stable ids). Rest is optional enrichment.

---

## Data quality caveats

| Issue | Mitigation |
|-------|------------|
| Missing English `label` | Fall back to `mul` label, `P373` commons name, or seed-list display name |
| Multiple `P123` publishers | Pick primary (e.g. FryxGames) or store first; document choice |
| Imprecise `P136` genre | Do not rely on genre for MVP picker |
| Wrong or sparse player counts | Validate against seed list; log warnings on import |
| Homonym search hits | Prefer Q-id or P2339 lookup over free-text search (e.g. Q86835554 is the video game) |
| SPARQL label search can be slow | Prefer `wbsearchentities` or fixed Q-id list for ~20 titles |

---

## Ruby gems and clients

No gem exposes “board game by title” end-to-end. Use a client for HTTP + parse, and own a **mapper** in the app.

| Gem | Notes |
|-----|--------|
| [`wikidata`](https://github.com/wilg/wikidata) | Modern; items, search, SPARQL; CLI `wikidata lucky "…"`; caching, User-Agent config |
| [`wikidata_adaptor`](https://github.com/huwd/wikidata_adaptor) | Wikibase REST API; read/write; Ruby ≥ 3.2 |
| [`wikidatum`](https://github.com/connorshea/wikidatum) | REST API client; lighter maintenance |

**Minimal without a gem** (Net::HTTP or Faraday):

```ruby
# 1) Search → pick Q-id from results
# 2) wbgetentities → parse claims hash
# 3) GameCatalog::WikidataMapper.call(entity_json) → attributes hash
```

For BGG-shaped work post-MVP (P-07), different adapters exist (`bgg_remote`, `board-game-gem`); not in F-02 scope.

---

## Implementation tips for F-02

### Seed list, not live search

For ~20 MVP titles, maintain `config/game_catalog/mvp_seed.yml` (or similar) with stable identifiers:

```yaml
# Prefer wikidata_id; bgg_id optional for disambiguation
- wikidata_id: Q36718832
  name: Terraforming Mars   # fallback if Wikidata label missing
- wikidata_id: Q…
  name: Catan
```

Import resolves by Q-id first; search-by-name only when Q-id omitted.

### Service shape

```ruby
GameCatalogImport.call(
  source: :wikidata,
  ids: %w[Q36718832 Q…],           # or read from MVP seed file
  dry_run: false
)
# → { imported: n, updated: n, skipped: n, errors: [...] }
```

- **Upsert** on `wikidata_id` (unique index).
- **Parameterized batch** — same entry point for 20 or 20_000 ids later (P-03 console/UI wraps this).
- **Provider adapter interface** — `WikidataAdapter#fetch_batch(ids)` returns normalized hashes; keeps P-07 swap isolated.

### Rate courtesy

- Wikidata Query Service: avoid hammering; batch SPARQL where possible.
- Action API: set a meaningful `User-Agent` (Wikimedia policy); optional short sleep between large batches.
- Cache responses in import runs (idempotent re-import should not re-hit API if data unchanged — optional optimization).

### Name resolution helper

```ruby
def display_name(entity)
  entity.dig('labels', 'en', 'value') ||
    entity.dig('labels', 'mul', 'value') ||
    claim_string(entity, 'P373') ||  # commons category
    seed_name
end
```

### Fields to persist (suggested minimum)

```ruby
# games table (illustrative)
# name              string, not null
# wikidata_id       string, unique, not null
# bgg_id            string, nullable, indexed
# min_players       integer, nullable
# max_players       integer, nullable
# year_published    integer, nullable
# source            string, default: 'wikidata'
# imported_at       datetime
```

### Console invocation (MVP)

```ruby
# bin/rails runner or rails console
GameCatalogImport.call(source: :wikidata, seed: :mvp)
```

### Testing

- **VCR / WebMock** against recorded `wbgetentities` JSON for 1–2 fixtures (Terraforming Mars + one sparse item).
- Unit-test mapper in isolation from HTTP.
- Contract test: import twice → no duplicate rows, updated counts only when Wikidata data changes.

### Attribution

CC0 does not require attribution, but good practice: store `source: 'wikidata'` and optionally link `https://www.wikidata.org/wiki/{id}` in admin/debug views later (P-03).

---

## References

- [Wikidata Query Service](https://query.wikidata.org/)
- [Wikidata:SPARQL](https://www.wikidata.org/wiki/Wikidata:SPARQL)
- [WikiProject Board Games](https://www.wikidata.org/wiki/Wikidata:WikiProject_Board_Games)
- [Wikidata licensing (CC0)](https://www.wikidata.org/wiki/Wikidata:Licensing)
- Action API docs: [wbsearchentities](https://www.mediawiki.org/wiki/Wikibase/API#wbsearchentities), [wbgetentities](https://www.mediawiki.org/wiki/Wikibase_API#wbgetentities)

---

## Open items for `/10x-plan`

- Pick gem vs plain HTTP for MVP ( lean toward `wikidata` gem or thin Faraday client ).
- Final MVP seed list (~20 Q-ids or BGG ids → resolved to Q-ids).
- Exact columns on `games` and whether to store raw import payload for debugging.
- Error policy: skip bad rows vs fail whole batch.
