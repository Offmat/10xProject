# Capybara E2E Prep — Plan Brief

> Full plan: `context/changes/capybara-e2e-prep/plan.md`
> Research: `context/archive/2026-09-06-e2e-tooling-choice/analysis.md`

## What & Why

Wire **Capybara + Cuprite** system specs for all-aBoard, ship one **fidelity seed** that protects silent multi-player drop on the Stimulus session form, put that seed in **CI**, and add **`/10x-e2e-capybara`** so agents follow M3L4 discipline without patching the course Playwright skill.

## Starting Point

RSpec + request/service specs only; no browser runner. Auth is `cookies.signed[:session_id]`. Test-plan Phase 1 and Phase 4 are not started. Tooling decision already chose Capybara over Playwright-as-suite.

## Desired End State

`bin/rspec` (local + GHA) runs Cuprite system specs; seed proves friend+guest survive real form submit; `/10x-e2e-capybara` is the project E2E skill; foundation docs match reality.

## Key Decisions Made

| Decision | Choice | Why | Source |
|----------|--------|-----|--------|
| Primary runner | Capybara system specs | Rails/RSpec fit; prior tooling analysis | Archive |
| Driver | Cuprite | Pure Ruby CDP; no Node browsers | Plan |
| Scope | Floor + fidelity seed | 6C overrides floor-only for seed content | Plan |
| Auth | Extend `sign_in_as` (cookie for system) | No UI login dependency | Plan |
| CI | Required in `test` job | Closes Phase 4 floor | Plan |
| Skill | New `10x-e2e-capybara` fork | No drift from course `10x-e2e` | Plan |
| Docs | test-plan + interactive-forms | Foundation stays truthful | Plan |

## Scope

**In scope:** Gemfile Cuprite/Capybara, system auth helper, fidelity seed, GHA Chrome, new skill + references, foundation/AGENTS updates.

**Out of scope:** Playwright Node suite, editing course `10x-e2e`, auth E2E, full Phase 1 request-oracle pass, vision/pixel, multi-browser matrix.

## Architecture / Approach

Cuprite drives headless Chrome under RSpec `type: :system`. Cookie sign-in mirrors production session cookie. One risk-tied seed asserts DB participants after Stimulus form submit. Agents use forked skill with Capybara rules; CI runs the same suite.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|------------------|----------|
| 1. Wire Cuprite + auth | Gems, driver, system `sign_in_as` | Cookie sign-in mismatch with signed jar |
| 2. Seed fidelity | System spec for risks #1–#2 | Flaky Stimulus waits under Cuprite |
| 3. CI floor | Chrome in GHA, required gate | Missing Chromium / sandbox in Actions |
| 4. Skill fork | `10x-e2e-capybara` + pointers | Incomplete remap vs lesson workflow |
| 5. Foundation sync | test-plan + interactive-forms + AGENTS | Phase 1 status overstated |

**Prerequisites:** Chrome/Chromium locally; Postgres for tests; accepted prior Capybara decision.
**Estimated effort:** ~2–3 focused sessions across 5 phases.

## Open Risks & Assumptions

- Cuprite may surface Hotwire races that Selenium would mask — correct waits are mandatory.
- GHA may need an explicit Chrome install step despite `ubuntu-latest`.
- Phase 1 “done” in test-plan should not claim request-oracle tightening unless separately completed.

## Success Criteria (Summary)

- Seed fails if a submitted player is dropped; passes when form+Stimulus+controller are healthy.
- CI `test` job runs system specs as a hard gate.
- Course `/10x-e2e` untouched; project agents pointed at `/10x-e2e-capybara`.
