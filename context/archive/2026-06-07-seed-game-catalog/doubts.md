# Implementation Doubts: SPARQL pivot (post-plan)

Short list of concerns for `/10x-impl-review`. The service layer was refactored from Action API (`wbgetentities` + claims mapper) to Wikidata Query Service (SPARQL + flat bindings mapper) after the original plan was written. Tests pass; these are behavioural and operational risks, not blockers if accepted explicitly.

## Plan drift

- **Original contract**: `WikidataClient.fetch` returns an `entities` hash; `WikidataMapper.call(entity, seed_name:)` maps one entity. Research explicitly chose `wbgetentities` for known Q-ids (rank handling, unit URIs, `labels.mul`).
- **Current code**: Client returns SPARQL `bindings` array; Mapper maps the full batch with `seed_names:` hash. Architecture (3 classes, ImportService upsert) is preserved; **HTTP boundary and mapper contract changed**.
- **Review question**: Is this drift documented in `change.md` / plan Progress, or should the plan be updated before archive?

## Data quality regressions (accepted SPARQL risk)

### D1 — Non-deterministic row selection

- **Where**: `WikidataMapper#call` uses `rows.first` after `group_by` when multiple bindings share the same `?game`.
- **Why it matters**: SPARQL `OPTIONAL` combinations can multiply rows (e.g. several `P1872` / `P2047` values). First row order is not guaranteed; `bgg_id`, player counts, or play time may vary between imports.
- **Previous behaviour**: `wbgetentities` exposed all statements with `rank`; mapper preferred `preferred` > `normal` > `deprecated`.
- **Mitigation options**: Pick row with most populated fields; aggregate in SPARQL (`SAMPLE`, subquery, or property-level sub-SELECTs); or document as known limitation.

### D2 — Play time unit conversion dropped — **FIXED**

- **Where**: `integer_value(row, 'playTime')` treats SPARQL value as minutes.
- **Why it matters**: `P2047` is often in hours (`wd:Q11579`). Example: Pandemic may persist `2` instead of `120` minutes.
- **Previous behaviour**: Mapper checked quantity unit URI (`Q7727` minutes, `Q11579` hours × 60).
- **Fix**: SPARQL query now uses `p:P2047/psv:P2047` with `wikibase:BestRank` to decompose quantity into amount + unit, then `BIND(IF(?unit = wd:Q11579, ?raw * 60, ?raw) AS ?playTime)` converts hours to minutes server-side. Mapper receives already-converted values.

### D3 — Statement rank no longer considered — **WONT-DO**

- **Where**: Entire SPARQL path.
- **Why it matters**: Deprecated or duplicate statements (e.g. old `min_players`) can surface instead of the preferred value when row selection is arbitrary.
- **Resolution**: Non-issue. The `wdt:` prefix returns only "truthy" values — highest-rank, non-deprecated statements. This is equivalent to the old `RANK_ORDER` sorting but handled server-side by Wikidata. Play time (P2047) uses `wikibase:BestRank` explicitly. No action needed.

## Operational risks

### D4 — GET with full query in URL

- **Where**: `WikidataClient#perform_request` encodes the entire SPARQL string as a GET query parameter.
- **Why it matters**: Fine for ~20 Q-ids (MVP seed). Large batches (P-03) risk URL length limits and proxy timeouts. Wikidata recommends POST for longer queries.
- **Mitigation**: Switch to `Net::HTTP::Post` before scaling batch size; optional chunking of `VALUES` clauses.

### D5 — SPARQL endpoint reliability and rate limits

- **Where**: `https://query.wikidata.org/sparql` (separate from `www.wikidata.org` Action API).
- **Why it matters**: Shared public Query Service; 429/503 under load. Client retries once on timeout/5xx only; 429 fails immediately (by design). No sleep between chunks (N/A today — single query).
- **Mitigation**: Manual import retry; backoff on 429; monitor warnings/skipped counts in rake output.

### D6 — Label fallback narrower than before

- **Where**: SPARQL `wikibase:language "en,mul"` + `seed_names` fallback in mapper.
- **Why it matters**: Covers the Terraforming Mars `mul` case. No fallback to `P373` (Commons category) or per-row `seed_name` — only batch `seed_names[wikidata_id]`. Acceptable if seed YAML always has fallback `name`.
- **Mitigation**: Keep seed names accurate; optional log when `name` resolves only via `seed_names`.

## Minor consistency nits

- ImportService warning text still says `"not returned by Wikidata API"` — should say SPARQL / Query Service.
- Mapper no longer logs when label and `seed_names` both miss (validation skips record; operator sees warning from ImportService).
- Class names (`WikidataClient`, `WikidataMapper`) still fit; behaviour is SPARQL-specific — fine unless P-07 expects a provider-agnostic client interface.

## D7 — Seed list Q-IDs were wrong — **FIXED**

- **Found**: 2026-06-08 via live SPARQL validation against Wikidata.
- **Severity**: Critical — 19 of 20 Q-IDs in `mvp_seed_list.yml` pointed to wrong entities (velvet fabric, Grammy awards, Portuguese architects, etc.). Only Q36718832 (Terraforming Mars) was correct.
- **Root cause**: Q-IDs were likely generated without live verification during plan authoring.
- **Fix**: All 20 Q-IDs replaced with verified values. Test seed list and fixtures updated accordingly.
- **Lesson**: Always validate Wikidata Q-IDs with a live query before committing a seed list.

## Live SPARQL validation results (2026-06-08)

Query ran against all 20 corrected Q-IDs. Key observations:

| Observation | Detail |
|---|---|
| **D1 confirmed** | 31 rows returned for 20 games. Wingspan: 6 rows (3 maxPlayers × 2 playTime). Agricola, Codenames, Brass, Gloomhaven, Spirit Island, Ticket to Ride also have duplicate rows. `group_by` + `first` handles it non-deterministically. |
| **D2 verified** | Play time values are in minutes after BIND conversion. Terraforming Mars = 120, 7 Wonders = 30, Ticket to Ride = 30/60. No raw hour values. |
| **D3 verified** | `wdt:` truthy prefix filters deprecated values correctly — no deprecated statements in results. |
| **Label fallback** | Catan returns as "The Settlers of Catan" from Wikidata; `seed_names` fallback provides "Catan" when preferred. Terraforming Mars label comes from `mul` language. |
| **Coverage** | All 20 games have BGG IDs. 20/20 have player counts. 20/20 have publication dates. Only 8/20 have play time data — the rest return nil (acceptable). |
| **Data quality** | Some games have multiple truthy values: Wingspan maxPlayers = {2, 5, 7}; Agricola maxPlayers = {4, 5}; Codenames pubDate = {2015, 2016}. First row wins — good enough for MVP. |

## Suggested manual verification (live SPARQL import)

After `bin/rails game_catalog:import`, spot-check:

| Q-id | Check |
|------|--------|
| `Q36718832` | Terraforming Mars: name (mul label), full field set, playTime=120 |
| `Q17271` | Catan: name uses seed_name fallback ("Catan" vs "The Settlers of Catan"), players=3-4, year=1995 |
| `Q531592` | Pandemic: players=2-4, playTime nil (no P2047 data in Wikidata) |
| `Q65784798` | Wingspan: deduplication works despite 6 rows; check which player counts landed |
| Re-run import | Idempotent counts; no duplicate `wikidata_id` |

## Overall assessment

The refactor is **cleaner and shorter**. D2 is fixed (unit conversion in SPARQL). D3 is wont-do (handled by `wdt:`). D7 (wrong Q-IDs) is fixed. For MVP (~20 known Q-ids + seed fallbacks), risk is **manageable**. Remaining follow-ups before larger imports (P-03): **D4 (POST/chunking)**, **D1 (row deduplication via GROUP BY + SAMPLE)**.
