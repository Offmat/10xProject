<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Tailwind CSS + daisyUI Setup

- **Plan**: `context/changes/tailwind-daisyui-setup/plan.md`
- **Mode**: Deep
- **Date**: 2026-06-07
- **Verdict**: REVISE
- **Findings**: 1 critical 3 warnings 0 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | WARNING |
| Lean Execution | WARNING |
| Architectural Fitness | WARNING |
| Blind Spots | FAIL |
| Plan Completeness | PASS |

## Grounding
9/9 paths ✓, 6/6 symbols ✓, brief↔plan ✓

## Findings

### F1 — CI and setup parity stop short of the real test paths

- **Severity**: ❌ CRITICAL
- **Impact**: 🔬 HIGH — architectural stakes; think carefully before deciding
- **Dimension**: Blind Spots
- **Location**: Desired End State / Phase 1 / Phase 3
- **Detail**: The plan promises "CI passes without modification" and leans on `tailwindcss:build` being hooked into `test:prepare`, but the repo's actual test paths do not guarantee that. GitHub Actions runs `bin/rails db:test:prepare` and then `bin/rspec`; local CI runs `bin/setup --skip-server` and then `bin/rspec`; `spec/rails_helper.rb` does not invoke `test:prepare`. Once the layout switches to `stylesheet_link_tag "tailwind"` and `app/assets/builds/` is ignored, CI/fresh-clone environments do not have a guaranteed CSS build or npm dependency install. The plan can therefore succeed in development while still failing its own CI and production-verification end state.
- **Fix A ⭐ Recommended**: Pull environment parity into Phase 1 by explicitly updating `bin/setup`, `config/ci.rb`, `.github/workflows/ci.yml`, and the Tailwind/npm build steps before any view depends on `tailwind.css`.
  - Strength: Every environment is aligned before the layout or views rely on built CSS; implementer does not have to discover hidden test-path behavior mid-stream.
  - Tradeoff: Phase 1 gets broader and a little less "just tooling."
  - Confidence: HIGH — the current repo wiring already proves the gap across local CI, GitHub Actions, and Docker.
  - Blind spot: Whether you want CI to build CSS explicitly or via a setup wrapper is still a design choice.
- **Fix B**: Keep pipelines mostly unchanged by committing generated `app/assets/builds/tailwind.css` and treating it as a checked-in artifact.
  - Strength: Minimizes CI changes and can make tests/layout rendering work without extra build steps.
  - Tradeoff: Adds generated-asset churn, staleness risk, and a workflow that diverges from the watcher/build model in the rest of the plan.
  - Confidence: MEDIUM — workable, but it changes the repository contract more than the plan currently acknowledges.
  - Blind spot: The long-term maintenance cost of committing builds has not been weighed against Rails/Tailwind conventions here.
- **Decision**: FIXED — Applied Fix A

### F2 — Shared flash partial will double-render auth messages

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Architectural Fitness
- **Location**: Phase 2 — Create flash partial / Update application layout
- **Detail**: The plan adds `render 'shared/flash'` to the layout, but current auth templates already render `flash[:alert]` and/or `flash[:notice]` inline. On sign-in/sign-up/password pages, the same message would appear twice unless those inline blocks are removed. This also means the plan touches auth templates even though auth restyling is said to be deferred.
- **Fix**: Add an explicit sub-step listing the four auth templates whose inline flash blocks should be removed while leaving the rest of those views functionally unchanged.
- **Decision**: FIXED — Added explicit auth-template flash cleanup step

### F3 — The layout shell creates a nested `<main>` unless the home page changes too

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: End-State Alignment
- **Location**: Phase 2 — Update application layout / Restyle home page
- **Detail**: The plan makes the application layout own a `<main>` container, but the current home page already uses `<main class="home">` as its root element. The document can meet the plan's visual goals while still shipping invalid nested main landmarks and fuzzy responsibility for page-level spacing.
- **Fix**: Make the layout's `<main>` the only main landmark and change the home page root element to a `<section>` or `<div>` during the restyle.
- **Decision**: FIXED — Kept a single layout-owned main landmark

### F4 — Phase ordering leaves shared setup behind the first manual checkpoint

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Lean Execution
- **Location**: Phase 1 vs Phase 3
- **Detail**: Phase 1's success criteria require `npm install`, a working Tailwind watch process, and a usable `bin/dev`, but the repo-level setup path (`bin/setup`) is not updated until Phase 3. That means the plan's first "pause for manual confirmation" can be green only on the implementer's machine, not on a fresh checkout following repo conventions.
- **Fix**: Move the `bin/setup` change into Phase 1, or explicitly narrow the Phase 1 checkpoint to "existing workstation only" and accept that fresh-clone reproducibility is deferred.
- **Decision**: ACCEPTED
