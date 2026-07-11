<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Game Catalog Import Service (F-02)

- **Plan**: context/changes/seed-game-catalog/plan.md
- **Scope**: All Phases (1-3) of 3
- **Date**: 2026-06-08
- **Verdict**: NEEDS ATTENTION
- **Findings**: 0 critical, 2 warnings, 2 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | PASS |
| Architecture | PASS |
| Pattern Consistency | WARNING |
| Success Criteria | PASS |

## Architecture Assessment

The current 3-service split (WikidataClient / WikidataMapper / ImportService) is well-justified:

- **Single Responsibility**: each class changes for one reason (API mechanics / JSON schema / orchestration)
- **Testability**: Mapper is pure data in/out; Client tested with WebMock alone; ImportService stubs both
- **Future extensibility**: P-07 (BGG) → new Client + Mapper; P-03 (bulk) → Client already chunks at 50
- **Cohesion**: high within each class; coupling minimal

Alternatives rejected: 2-class (worse separation), 4-class (premature), different boundary (worse testability).

## Findings

### F1 — Mapper warnings bypass ImportService result

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: app/services/game_catalog/wikidata_mapper.rb:76, :102
- **Detail**: Plan states ImportService should "collect warnings from mapper." However, WikidataMapper logs warnings directly to Rails.logger.warn (unknown play time units, missing labels) — these never reach ImportService's result[:warnings] array. Operator running the rake task sees only ImportService-level warnings in stdout; mapper warnings appear only in Rails logs.
- **Fix**: Have WikidataMapper return a result struct/hash with both attributes and warnings (e.g. `{ attrs:, warnings: }`) and have ImportService aggregate them into its result.
  - Strength: Unified warning channel; operator sees all issues in one place. Matches plan contract exactly.
  - Tradeoff: Changes the Mapper interface; ripples into unit specs (~10 lines of spec refactoring).
  - Confidence: HIGH — standard pattern for pipelines that need to surface non-fatal issues.
  - Blind spot: None significant.
- **Decision**: FIXED — Mapper now returns `{ attrs:, warnings: }` and ImportService aggregates them.

### F2 — Unplanned P373 (Commons category) fallback in display_name

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: app/services/game_catalog/wikidata_mapper.rb:33
- **Detail**: Plan specifies label fallback: en → mul → seed_name. Implementation adds `string_claim(entity, 'P373')` (Commons category) between mul and seed_name. Benign addition providing better coverage for entities missing both en and mul labels, but undocumented in plan.
- **Fix**: Document in plan as an addendum (add note to Phase 2 WikidataMapper section mentioning P373 fallback).
  - Strength: Keeps plan as source of truth without removing a useful robustness improvement.
  - Tradeoff: Negligible — one-line addendum.
  - Confidence: HIGH — benign; removing it would be strictly worse.
  - Blind spot: None significant.
- **Decision**: FIXED — Plan addendum documents P373 fallback and new Mapper return format.

### F3 — WikidataClient::Error unrescued in ImportService

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: app/services/game_catalog/import_service.rb:10
- **Detail**: If Wikidata is completely unreachable (after the one retry), WikidataClient raises Error and the rake task crashes with a stack trace. Acceptable for an operator tool, but a rescue in the rake task printing a friendly message would be cleaner.
- **Fix**: Wrap `GameCatalog::ImportService.call` in the rake task with `rescue GameCatalog::WikidataClient::Error => e` and print a friendly error.
- **Decision**: SKIPPED

### F4 — save vs. save! resolves plan contradiction correctly

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — informational only
- **Dimension**: Plan Adherence
- **Location**: app/services/game_catalog/import_service.rb:37
- **Detail**: Plan's "Critical Implementation Details" says `save!`, but the same contract says "collects validation failures (logs + increments skipped counter instead of raising)". These are mutually exclusive. Implementation correctly chose `save` (without bang) to enable graceful degradation. No action needed.
- **Decision**: SKIPPED
