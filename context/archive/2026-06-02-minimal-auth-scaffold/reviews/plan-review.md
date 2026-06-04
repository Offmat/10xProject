<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Minimal auth scaffold

- **Plan**: context/changes/minimal-auth-scaffold/plan.md
- **Mode**: Deep
- **Date**: 2026-06-02
- **Verdict**: REVISE
- **Findings**: [0 critical] [3 warnings] [0 observations]

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | WARNING |
| Architectural Fitness | PASS |
| Blind Spots | WARNING |
| Plan Completeness | WARNING |

## Grounding
Grounding: 6/6 paths ✓, 3/3 symbols ✓, brief↔plan ✓

## Findings

### F1 — Test :null_store disables rate_limit verification

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Blind Spots
- **Location**: Phase 2 — Login rate limiting + Success Criteria 2.1
- **Detail**: config/environments/test.rb sets `config.cache_store = :null_store`. Rails 8's `rate_limit` uses `ActiveSupport::Cache` — `NullStore#increment` returns nil, so the throttle check (`count && count > to`) never fires. Phase 2 success criterion 2.1 requires rate-limit request specs, but those specs cannot exercise real throttling without a working cache store.
- **Fix A ⭐ Recommended**: Add :memory_store override for rate-limit specs
  - Strength: Targeted — only rate-limit specs switch store via around block or RSpec metadata. Rest of suite stays fast on :null_store.
  - Tradeoff: Adds spec setup boilerplate; must document for future spec authors.
  - Confidence: HIGH — standard Rails pattern for testing cached behavior.
  - Blind spot: None significant.
- **Fix B**: Switch test cache globally to :memory_store
  - Strength: One-line change in test.rb; all cache behavior becomes testable.
  - Tradeoff: May slow suite and introduce flaky state leakage between specs.
  - Confidence: MEDIUM — safe now but scales poorly.
  - Blind spot: Impact on other cache-dependent tests not surveyed.
- **Decision**: FIXED (Fix A) — added test caveat to Phase 2 Change 1

### F2 — Phase 2 rate limiting overlaps with generator defaults

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Lean Execution
- **Location**: Phase 2, Change 1 — Login rate limiting
- **Detail**: The Rails 8 auth generator already injects `rate_limit to: 10, within: 3.minutes, only: :create` into sessions_controller.rb and a similar line into passwords_controller.rb. Phase 2 treats login rate limiting as net-new work without acknowledging the generator baseline.
- **Fix**: Reframe Phase 2 Change 1 as threshold-tuning and audit-integration on top of generator-provided rate_limit, not build-from-scratch.
- **Decision**: FIXED — reframed Phase 2 Change 1 intent to acknowledge generator defaults

### F3 — PagesController allowlist and spec update not tracked

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 1, Change 3 — Authentication boundary in controllers
- **Detail**: After `include Authentication` adds a global `before_action :require_authentication`, PagesController#home (root route) will redirect unauthenticated users. The existing spec/requests/pages_spec.rb expects `GET /` → 200 without auth and will fail. Plan manual criterion 1.7 references public allowlist behavior but no Phase 1 task explicitly mentions PagesController or the spec.
- **Fix**: Add explicit PagesController `allow_unauthenticated_access` call to Phase 1 Change 3 contract; note pages_spec.rb removal since auth boundary specs subsume it.
- **Decision**: FIXED — added allowlist and spec removal note to Phase 1 Change 3 contract
