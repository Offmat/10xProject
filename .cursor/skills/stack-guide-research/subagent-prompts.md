# Sub-agent prompt templates

Read at step 3 of [SKILL.md](SKILL.md). Substitute `<…>` placeholders. Spawn all agents in a single message.

Every prompt must carry these four instructions, because they are what separates a usable report from a plausible one:

1. Absolute paths — cloned repos live outside the workspace, so relative paths silently resolve to the wrong tree.
2. Exact `path:line` references plus short excerpts (5–20 lines), never whole files.
3. **Counts.** "How many of the N units use X" turns opinion into evidence.
4. *"If a pattern is absent, say so explicitly; absence is a finding."*

---

## A. Production app (one per app) — `explore`

> Thoroughness: very thorough. Read-only analysis of a locally cloned production `<framework>` app: `~/<topic>-research/<app>` (`<org/app>`, `<what it is>`, ~`<N>` `<units>`). It is OUTSIDE the current workspace — read files with absolute paths.
>
> I am writing an engineering guide on `<topic>`. I need EVIDENCE of repeated patterns from this production codebase, with exact `absolute/path:line` references and short code excerpts (5–20 lines max each).
>
> 1. **Documented conventions**: read every root `*.md` (`AGENTS.md`, `STYLE.md`, `CONTRIBUTING.md`, `CLAUDE.md`), everything under `docs/`, and `.cursor/`. Quote verbatim every rule touching `<topic>` or its testing. Note file:line. If none exist, say so — that is a finding.
> 2. **Inventory**: list every `<unit>` (`<glob>`) with a one-line purpose and its line count. Give the size distribution (min/median/mean/max) and name the largest.
> 3. **Repeated design patterns** — for each, 2+ examples with file:line: naming; which APIs are used often vs rarely/never (give per-API counts); lifecycle and cleanup; how units communicate; where state lives (declared config vs instance fields vs DOM/DB vs server-rendered); scoping (how often is a global lookup used vs a scoped one — count both); shared helpers/base classes/mixins, or their absence.
> 4. **`<topic>` specifically**: find every file involved in `<the behaviour>`. For each, quote both sides of the boundary (e.g. template and controller, or job and caller) and explain the mechanism.
> 5. **Resilience**: how does the app stay correct across `<the framework's disruptive events>`? Search for the relevant event names and attributes; list what is used and what is conspicuously unused.
> 6. **Testing**: framework, layers, and tests that exercise `<topic>`. Give file:line examples and describe what they assert. Note whether unit tests for `<units>` exist at all.
>
> Do NOT modify any file. Do NOT summarize away specifics — I need quotable evidence and precise counts. Report absolute paths.

Lower thoroughness to "medium-to-thorough" for the second app; frame it as *corroborating* the first so you learn which patterns are conventions rather than one team's quirk.

## B. Official docs and source — `explore`

> Thoroughness: very thorough. Read-only extraction from locally cloned OFFICIAL repos (outside the workspace, absolute paths): `~/<topic>-research/<framework>` (`docs/`, `src/`, `test/`), `~/<topic>-research/<integration>`.
>
> I need the AUTHORITATIVE, doc-grounded facts (not your prior knowledge) for a guide on `<topic>`, each with `absolute/path:line` and a short quote.
>
> A. **Stated intent**: what the tool is for and what it explicitly is NOT for — quote the philosophy/origin pages.
> B. **Mechanics that matter to `<topic>`**: `<list the exact APIs: lifecycle, typed config, scoping/nesting rules, defaults, coercion, ordering guarantees>`. For each: exact semantics, how many times things fire, and behaviour when elements/records are removed, re-added or moved.
> C. **What breaks or preserves state**: `<the framework's replacement/caching/reconciliation mechanisms>`, their opt-in attributes and constraints, the full event list with a one-line meaning each, and anything documented about preserving in-progress user input.
> D. **Integration-layer defaults**: helpers relevant to `<topic>` and the defaults the integration sets.
>
> Where the docs are silent but `src/` implements the behaviour, cite the source file:line and mark it **"implementation, not documented"**. Where a functional test is the only proof, cite the test. If the handbook is not in the repo, say so and note where it lives. Be exhaustive on mechanics; skip tutorials.

## C. Community practice — `generalPurpose` (exactly one)

> You are doing WEB research (no codebase work) for an engineering guide on `<topic>` in `<stack>`. Use WebSearch, WebFetch, and Context7 MCP for library docs. Today is `<date>`; prefer sources from the `<current major version>` era.
>
> Goal: identify practices that appear CONSISTENTLY across MULTIPLE respected sources, and note where sources disagree. Respected = official project blogs, `<the framework team>`, and well-known practitioners in this ecosystem.
>
> Research these questions: `<8–10 numbered questions, each naming candidate approaches to compare>`.
>
> For EACH finding record: the concrete recommendation; WHY it exists (the failure it prevents); how many and which independent sources support it; disagreements; source URLs with titles and dates.
>
> Output as bullets: `**Recommendation** — why — supported by [Source A (date), Source B (date)] — disagreements/caveats`. Distinguish (a) broad consensus (3+ independent respected sources), (b) common but contested, (c) single-source opinion. Quote 5–20 line snippets where a pattern is canonical. End with a source list: title, author/site, date, URL, one-line credibility note.
>
> Constraints: do NOT invent URLs — report only pages you fetched successfully, and say which fetches failed. Flag any source that is a consultancy/SEO blog or an AI-generated summary, and cross-check its claims against a stronger source or against the actual repository. Report gaps in the literature explicitly.

## D. This project's current state — `explore`

> Thoroughness: medium. Work inside the current workspace `<abs path>` (`<stack summary>`). Read-only. I need a precise picture of the current state and near-term requirements for `<topic>`, with `path:line` references.
>
> 1. **Setup**: entry points, package/import configuration, which relevant packages are loaded and how (eager/lazy), and whether `<the optional features>` are configured anywhere.
> 2. **Existing usage**: every file already doing `<topic>`. For each: what it does, which mechanisms it uses, and any relevant attributes. Note structural conventions (partials, shared components, class/style patterns) and helpers already in use.
> 3. **Conventions and tooling**: quote every `<topic>`/testing rule from `AGENTS.md` files and `.cursor/rules/*.mdc` (list globs and `alwaysApply`). Note which linters/test frameworks exist — and which don't.
> 4. **Near-term requirements**: read the plan of the change this guide unblocks, plus the PRD/roadmap entries it cites. Summarize concretely what must be built, quoting the relevant sections (path:line).
> 5. **Domain objects it binds to**: models, services, migrations, validations the UI or caller must respect, and whether framework conveniences (`<e.g. accepts_nested_attributes_for>`) are used or deliberately avoided.
> 6. **Prior art**: grep `context/archive/**` and `context/changes/**` for prior decisions, deferrals and lessons about `<topic>`. One line each with path:line.
>
> Do NOT modify anything. Quote code and plan text where it matters. State absences explicitly (e.g. "no system specs exist").
