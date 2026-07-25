---
name: stack-guide-research
description: Research one part of the tech stack in depth and write a long-form engineering guide grounded in official docs, cloned production reference repos, and consistently-held community practice — graded by evidence strength, anchored to this project's next change, and ending with a review checklist plus candidate/non-candidate agent rules. Use when the user asks for a guide, playbook, deep research or best practices for a framework, library or stack area (forms, background jobs, caching, auth, deploys, testing), or names a change whose risk is "we keep doing this inconsistently". Not for codebase-only questions (use 10x-research) and not for writing the rules themselves.
disable-model-invocation: true
---

# Stack Guide Research

Produce a long-form engineering guide for one area of the tech stack, written to `context/changes/<change-id>/research.md`. Output is a *guide*, not rules — a later step distills rules from it.

The method's value comes from three things: **line-accurate citation of primary sources you cloned yourself**, **explicit evidence grading**, and **treating absence as a finding**. Skipping any of them produces confident prose that repeats the internet.

## Workflow

Copy this checklist and track it with your task-management tool:

```
- [ ] 1. Read the brief and project context
- [ ] 2. Pick and clone reference repos
- [ ] 3. Spawn parallel research agents
- [ ] 4. Wait for ALL agents, then synthesize
- [ ] 5. Verify load-bearing claims yourself
- [ ] 6. Write the document
- [ ] 7. Clean up clones, bump change.md, report
```

### 1. Read the brief and project context

Read fully, in the main context, before spawning anything: the user's brief; `context/changes/<change-id>/change.md`; `context/foundation/lessons.md`; the plan of the change this guide unblocks. Note what the project has decided already — a guide that contradicts a shipped decision is waste.

Skip scope questions when the brief is detailed. Ask (2–4 concrete options) only when the area, depth or the target change is genuinely ambiguous.

### 2. Pick and clone reference repos

Clone, don't summarize from blogs. Local clones give exact `path:line`, real line counts, and countable absences.

Pick 3–5 repos:

- **The framework's own repo** — `docs/`, `src/`, and `test/`. Functional tests document behaviour the docs omit; cite them as "implementation, not documented".
- **Two production apps** from a team that ships this stack. Two, not one, so a repeated pattern counts as a convention rather than a quirk.
- **The Rails/adapter integration repo** where relevant (e.g. `turbo-rails` for Turbo), since defaults often live there.

```bash
mkdir -p ~/<topic>-research && cd ~/<topic>-research
for r in org/framework org/prod-app-1 org/prod-app-2; do
  git clone --depth 1 -q https://github.com/$r.git $(basename $r)
done
for d in */; do printf "%s " "$d"; git -C "$d" rev-parse --short HEAD; done
```

Operational facts that will otherwise cost you time:

- Run clones with `required_permissions: ["all"]`. In the sandbox, `git clone` fails creating `.git/hooks` and `gh api` is blocked entirely.
- Clone to `~/<topic>-research`, **not** into the workspace — writes under the repo's ignored `tmp/` are also blocked, and clones must never land in git.
- **Record the short SHA of every clone** before you write anything; every citation is meaningless without it.
- The handbook may not be in the repo (Turbo's lives on its website). Check `docs/` first; fall back to Context7 MCP or `WebFetch`.

### 3. Spawn parallel research agents

One message, 4–5 agents. Match the agent type to the work:

| Agent | Use for | Notes |
|---|---|---|
| `explore` | each cloned repo; this project's current state | Cheap and precise. Cannot browse the web. |
| `generalPurpose` | community practice via WebSearch/WebFetch/Context7 | The only one that can research the web. Use exactly one. |

Prompt templates, including the wording that produced the best findings: [subagent-prompts.md](subagent-prompts.md).

Non-negotiables in every prompt: absolute paths (clones are outside the workspace), exact `path:line` plus short excerpts, **counts** (how many controllers/jobs/files use X), read-only, and — the highest-yield instruction of the set — *"If a pattern is absent, say so explicitly; absence is a finding."*

### 4. Wait for ALL agents, then synthesize

Never compile or present while an agent is still running (`context/foundation/lessons.md`). If one is slow, ask the user whether to wait or proceed without it.

Grade every claim as you merge:

- **Consensus** — 3+ independent respected sources, or documented in the framework *and* observed in both production apps. State flatly.
- **[contested]** — respected sources disagree. Say who, and give the decision rule instead of a verdict.
- **[single source]** — one source. Label it so a later reader can overrule it cheaply.

Discount aggressively: consultancy/SEO blogs with unverifiable production anecdotes, and "conventions of $TEAM" artifacts that are AI-generated summaries of a codebase. Check the latter against the code — in this session a widely-cited "37signals Stimulus style guide" gist turned out to describe rules that don't exist and a controller count that was stale.

### 5. Verify load-bearing claims yourself

Before writing, personally check anything where being wrong changes code:

- Framework *parsing or lifecycle* semantics you're about to recommend (this session: nested params only work when every index key is numeric — which invalidated the example every tutorial publishes).
- API shapes you'd assert without having run them. Prefer "verify X before committing" plus an Open Question over a confident sentence.
- Whether the project's plan matches what shipped. Plan-vs-implementation drift found in passing is worth recording.

When verification contradicts something you already wrote or said, correct it plainly and move on.

### 6. Write the document

Path: `context/changes/<change-id>/research.md`. Long documents need multiple passes — `Write` the first third, then extend with `StrReplace` on a sentinel comment. Do not thin the content to fit one call.

Frontmatter and the shared sections follow `10x-research`: `date`, `researcher`, `git_commit`, `branch`, `repository`, `topic`, `tags`, `status`, `last_updated`, `last_updated_by`; then `## Research Question`, `## Summary`, `## Detailed Findings`, `## Code References`, `## Architecture Insights`, `## Historical Context (from prior changes)`, `## Related Research`, `## Open Questions`. Real values only, never placeholders.

Guide-specific structure inside that skeleton:

```markdown
## Summary
Lead with the finding that changes what the reader does. Then 8–12 numbered
principles, each one line, each traceable to the body. Flag headline negative
findings here — they are often the most valuable output.

## Evidence base
Source classes in priority order + the clone table (repo | commit | path).
Note explicitly what is NOT in the repos (e.g. handbook lives on the website).
State the grading labels used.

## Detailed Findings
### 1. Division of responsibilities   ← who owns what: server / framework / library / this tool
### 2. The escalation ladder          ← cheapest mechanism first; when to escalate
### 3. State ownership                ← a table: which state, which owner, which mechanism, why
### 4–N. Area topics from the brief   ← one section per topic, each with rationale,
                                        benefits, drawbacks, example, common mistake
### N+1. Notes for AI coding agents   ← failure modes this area invites; label extrapolation
### N+2. Applying this to <project>   ← measured current state, the concrete worked example
                                        for the next change, and an explicit "do NOT do" list

## Architecture Insights
### Notable absences (what the evidence does *not* show)
Every countable zero, plus what each one means for how much authority the guide
claims. Include absences that qualify your own recommendations.

## Deliverable 1: Code-review checklist
Grouped, checkbox form, ordered so the fastest bug-finders come first.

## Deliverable 2: Candidates for agent rules
Falsifiable only — a reviewer or grep can decide compliance. Prohibitions first.

## Deliverable 3: Recommendations that should NOT become rules
Anything needing judgement, with the reason it resists a fixed rule.
```

Rules for the body: every recommendation carries rationale, benefit, drawback, example and the mistake it prevents. Quote 5–20 line excerpts, never whole files. Prefer a real production example over a toy one, and say why that implementation is good. Optimize for practical guidance, not brevity.

### 7. Clean up, bump change.md, report

- `rm -rf ~/<topic>-research`.
- In `change.md`: set `updated`, advance `status: new` → `preparing`, and add a note listing the **repo@SHA** set used plus the re-clone command, so a citation can be re-checked later.
- Refuse to write under `context/archive/` — tell the user to open a new change instead.
- Report to the user: the headline finding, any correction the research forced on the project's existing plan, and the open questions that need a decision before implementation.

## Quality bar

The document is done when a reader can answer, without leaving it: who owns each piece of state; which mechanism to reach for first and when to escalate; what the production apps actually do (with counts); which recommendations are consensus versus contested; what the evidence does *not* support; and exactly what to write for the next change in this repo.
