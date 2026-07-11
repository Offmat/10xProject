<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Game Catalog Import Service (F-02)

- **Plan**: context/changes/seed-game-catalog/plan.md
- **Mode**: Deep
- **Date**: 2026-06-07
- **Verdict**: SOUND
- **Findings**: 0 critical, 1 warning, 1 observation

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | PASS |
| Architectural Fitness | PASS |
| Blind Spots | WARNING |
| Plan Completeness | WARNING |

## Grounding

Grounding: 7/7 paths ✓, 3/3 symbols ✓, brief↔plan ✓

## Findings

### F1 — Integration test fixture covers 3 entities but seed list has 20

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Blind Spots
- **Location**: Phase 3 item 4 (integration test) + Phase 2 item 7 (ImportService contract)
- **Detail**: The integration test (Phase 3) calls `ImportService.call` with its default seed file (20 games) but stubs Wikidata to return `wbgetentities_batch.json` — a fixture with only 2–3 entities. The `entities` hash in the response won't have keys for ~17 of the 20 Q-ids. The plan never specifies what ImportService does when an entity is absent from the API response (different from an entity with missing claims — that IS handled via nullable fields). Without this, the integration test either blows up with KeyError/NoMethodError on the 4th seed entry, or creates only 2–3 games + 17 skips, making "creates expected number of games" ambiguous.
- **Fix A ⭐ Recommended**: Test-specific seed file + missing-entity contract
  - Strength: Clean test isolation. The ImportService gets an explicit contract for missing entities (skip + warn), which also documents behavior for wrong Q-ids in production.
  - Tradeoff: One extra fixture file (`spec/fixtures/wikidata/test_seed_list.yml` with 2–3 entries matching the JSON fixture). Trivial maintenance.
  - Confidence: HIGH — this is the standard pattern for integration tests with stubbed external APIs.
  - Blind spot: None significant.
- **Fix B**: Expand fixture to cover all 20 entities
  - Strength: Tests the production seed list end-to-end; no custom test data.
  - Tradeoff: Large, brittle fixture (~500+ lines of JSON). Must be updated whenever the seed list changes. Doesn't resolve the missing-entity contract gap.
  - Confidence: LOW — maintaining a 20-entity JSON fixture is disproportionate for an integration test.
  - Blind spot: Still doesn't specify ImportService behavior for missing entities in production use.
- **Decision**: FIXED via Fix A — added missing-entity skip+warn to ImportService contract; integration test now uses test-specific seed file

### F2 — Mapper label-fallback terminal behavior ambiguous

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 2, items 5–6 (WikidataMapper contract vs spec)
- **Detail**: The mapper spec contract says "label fallback chain (en → mul → seed_name → nil raises)" — implying the mapper raises when no name is resolvable. But the mapper contract says "Logs warnings via Rails.logger.warn for: missing labels with no seed_name fallback" — implying it returns nil. These describe different error strategies. Either works (raise = fail-fast; nil = let ImportService's validation-failure handler catch it), but the implementer has to guess which one the plan intends.
- **Fix**: Pick one and align both sections. Recommendation: mapper returns nil for name + logs warning; ImportService catches the validation failure and increments `skipped`. This matches the plan's overall "persist what you can, warn about the rest" philosophy.
- **Decision**: FIXED — aligned mapper spec to "nil returns nil + logs warning" (consistent with mapper contract)
