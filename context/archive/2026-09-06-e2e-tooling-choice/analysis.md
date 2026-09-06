# E2E tooling choice — Playwright vs alternatives for all-aBoard

**Date:** 2026-09-06  
**Sources:** course lesson M3L4 (`m3l4-testy-e2e-playwright-mcp-i-multimodalne-scenariusze.md`), `context/foundation/tech-stack.md`, `context/foundation/test-plan.md`, `context/foundation/prd.md`, current Gemfile / package.json, skill `/10x-e2e`, archived interactive-forms research.

## Verdict

**Playwright is a strong tool for agent-driven E2E — but it is not the best primary choice for this project’s CI browser layer.**

For all-aBoard, prefer **Capybara system specs (RSpec)** as the default browser E2E runner. Keep Playwright (CLI / optional MCP) only if you explicitly want the course `/10x-e2e` agent loop as a second, agent-facing surface — or adapt `/10x-e2e` references to Capybara idioms and skip installing Playwright as the suite runner.

Do **not** adopt Stagehand, Cypress, or vision/MCP as the MVP browser strategy.

---

## Stack facts that drive the decision

| Fact | Implication |
|------|-------------|
| Rails 8.1 + Hotwire (Turbo Drive / Stimulus) + importmap | Browser risk is mostly **server-rendered forms + modest JS**, not a SPA API client |
| RSpec already wired (`bin/rspec`, GHA, ~22 specs); no Capybara, no Playwright yet | Adding *one* browser runner is enough; two stacks doubles flake/CI cost |
| `test-plan.md` already names **Capybara system specs** for risks #1–#2 and Phase 1/4 | Changing to Playwright means revising a frozen strategy, not a greenfield pick |
| Top browser risks: multi-player form POST fidelity; Stimulus param shape vs controller | Needs a **real browser submit**, not vision and not full auth journeys |
| Solo, after-hours, 3-week MVP budget; no AI/LLM product features | Token-heavy MCP/vision and dual runtimes are poor cost × signal |
| `package.json` only has daisyUI; Node is build-time for CSS | Playwright adds a **second test runtime** (Node + browsers) beside Ruby |
| `/10x-e2e` skill is installed and Playwright-tuned | Course path assumes Playwright; skill itself says other tools work if seed/rules are remapped |

---

## What the lesson actually recommends

M3L4 is not “Playwright or nothing.” Core claims that transfer to any stack:

1. **E2E only for cross-boundary / rendered-UI risks** — else unit/request.
2. **Don’t generate E2E from scratch** — risk from `test-plan.md` + seed + quality rules.
3. **Loop:** PLAN → GENERATE → REVIEW (5 anti-patterns) → VERIFY (green + deliberate break).
4. **Agent sees accessibility tree**, so prefer role-based locators.
5. **CLI over MCP by default** (~4× fewer tokens); vision only for layout/z-index/canvas.
6. **Internal boundaries real; mock only flaky external APIs.**
7. **Non-Playwright stacks:** rewrite seed/rules to that tool’s idioms; principles stay.

Playwright is the *default packaging* of that workflow (CLI, MCP, Test Agents, seed.spec.ts), not a claim that Capybara cannot protect the same risks.

Alternatives the lesson names:

| Tool | Lesson stance | Fit for all-aBoard |
|------|---------------|--------------------|
| Playwright | Default for course + agents | Excellent for agent generation; heavier for Rails-only CI |
| Stagehand | Alternative (NL + AI); less determinism | Poor — scraping/unowned sites, not product regression |
| Cypress / WebdriverIO / Selenium | Supported via remapped rules | Cypress = second JS ecosystem; Selenium alone is weaker DX; Cuprite/Selenium under Capybara is the Rails path |
| Deterministic visual diffs | Prefer over vision models | Out of MVP budget (test-plan already says so) |

---

## Option comparison for this repo

### A. Capybara system specs (recommended primary)

**Pros**

- Matches `test-plan.md` Phase 1 + 4 and rspec-rails guidance.
- Same process as request/model specs (`bin/rspec`); one CI mental model.
- Natural for Hotwire: full Rails stack, Turbo submit, Stimulus DOM — exactly risks #1–#2.
- Aligns with prior research (interactive forms archive: 37signals-style system tests; driver Selenium/Cuprite/`capybara-playwright-driver` all sit under Capybara).
- Auth helpers (`sign_in_as`) already exist for request specs; system layer can reuse cookie/session patterns without inventing `storageState` in TypeScript.
- No new Node test harness for MVP.

**Cons**

- Weaker out-of-the-box agent browser tooling than Playwright CLI/MCP (no first-class accessibility YAML snapshot loop in course materials).
- `/10x-e2e` references need remapping (seed → `spec/system/..._spec.rb`, rules → Capybara matchers / `have_*`, no `getByRole` verbatim).
- Parallel isolation / `storageState` idioms differ; must encode them in Ruby rules.

### B. Playwright as primary E2E suite

**Pros**

- Drop-in with `/10x-e2e`, seed.spec.ts, CLI exploration, optional MCP.
- Strong agent ergonomics (snapshot → `getByRole` tests).
- `storageState`, network mocking, traces — mature for multi-boundary flows.
- Can drive the same session-form risks if the app is up (`bin/dev` / `webServer`).

**Cons**

- Diverges from written test-plan (explicit Capybara choice).
- Second language/runtime in CI (Node + browser binaries) beside RSpec.
- Auth/session setup duplicated vs Ruby helpers unless carefully bridged.
- Overkill for “Stimulus posted wrong nested params” unless you also invest in agent generation ROI.
- Healer / vision features are irrelevant or harmful for MVP risk budget.

### C. Hybrid (Capybara for CI + Playwright for agent exploration)

**Pros**

- Protects product risks in the suite you already planned.
- Still lets you practice M3L4 / use Playwright CLI while coding.

**Cons**

- Two tools to maintain; easy to duplicate the same scenario.
- Only worth it if agent exploration clearly speeds authoring *and* you commit to one source of truth in CI (Capybara).

### D. Cypress / Stagehand / vision-first

Rejected for MVP: wrong ecosystem fit, non-determinism, or cost × signal already ruled out in `test-plan.md` §4–§5.

---

## Mapping lesson risks to all-aBoard

| Lesson example (10xCards) | all-aBoard analogue | Cheapest layer (existing plan) |
|---------------------------|---------------------|--------------------------------|
| Flashcards lost after reload (auth→API→DB→SSR) | Session players silently dropped on submit | system (browser) + request oracles |
| Unauthenticated access to protected resources | IDOR confirm/reject | **request** (Phase 2 done) — not E2E |
| Mock external LLM HTTP | Wikidata import | WebMock — not browser |

Lesson discipline (“few E2E, risk-tied, deliberate break”) **agrees** with test-plan principle #1. The disagreement is only **which runner** executes the browser layer.

---

## Recommendation (actionable)

1. **Keep Capybara system specs as the canonical browser E2E** for risks #1–#2 and Phase 4 CI floor. Do not rewrite `test-plan.md` §4 to Playwright unless you deliberately reopen the strategy.
2. **Treat M3L4 process as portable:** seed system spec + E2E quality rules in Ruby + `/10x-e2e`-style review/verify — optionally by adapting skill references to Capybara (lesson’s optional task).
3. **Install Playwright only if** you want agent-driven exploration (CLI) or TypeScript specs as a learning exercise — then do **not** duplicate the session-form fidelity test in both runners; CI stays on Capybara.
4. **Skip for MVP:** Playwright MCP as default, `--caps=vision`, Stagehand, full auth browser suite, pixel snapshots.
5. **Driver under Capybara:** start with Selenium headless Chrome (Rails default) or Cuprite; `capybara-playwright-driver` is optional later if you want Playwright’s engine *without* leaving the RSpec suite.

---

## Decision summary

| Question | Answer |
|----------|--------|
| Is Playwright a good tool? | Yes — especially for AI agents and course workflow. |
| Is it the best primary choice for this stack? | **No** — Capybara system specs fit Rails/Hotwire/RSpec and the existing test plan better. |
| What to do with `/10x-e2e`? | Use its **discipline**; either remap levers to Capybara or use Playwright only as an optional agent aid. |
| Next product step | Open test-plan Phase 1 (session-form player fidelity) with Capybara — not a greenfield Playwright bootstrap. |

---

## Suggested follow-ups

- `/10x-plan e2e-tooling-choice` — only if you want a formal plan to *change* `test-plan.md` (e.g. adopt Playwright as primary). If the verdict above is accepted, archive this change and execute Phase 1 of the existing test plan instead.
- If adapting `/10x-e2e` to Capybara: seed system spec + Ruby rules file under `spec/` / AGENTS.md; keep anti-patterns checklist as-is (tool-agnostic).
