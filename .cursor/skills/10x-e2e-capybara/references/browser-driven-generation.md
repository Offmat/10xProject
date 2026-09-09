# Browser-Driven Generation with Capybara + Cuprite

Plan from what the Rails app actually renders, then generate a system spec from
that evidence. The seed (`seed-test-pattern.md`) and quality rules remain
authoritative.

```text
PLAN      → explore the real flow and map actions/outcomes for one risk
GENERATE  → execute with Cuprite and write one RSpec system example
REVIEW    → check the five named anti-patterns
VERIFY    → run green, deliberately break the protected behavior, confirm red
```

## Ways to explore

1. **Drive through Capybara (preferred).** Use a temporary system example or the
   target example itself with `visit`, Capybara interactions, `page.text`,
   labels, and waiting matchers. Run it with `bin/rspec <path>`.
2. **Inspect the app code.** Read routes, views, form partials, and Stimulus
   controllers when the flow is clear enough without temporary browser code.
3. **Manual browser exploration.** Use visible labels and names to map the flow.
4. **Playwright CLI/MCP (optional only).** It may help inspect accessibility
   names, but it is never required by this skill and does not determine the test
   syntax or runner.

Prefer accessible names and labels over screenshots. Screenshots can diagnose a
visual failure but do not replace assertions on behavior.

## PLAN

- Start with one risk from `context/foundation/test-plan.md` or the approved
  change plan, not a generic page crawl.
- Read `spec/system/game_sessions/player_fidelity_spec.rb`.
- Identify setup records, `sign_in_as` authentication, route, user actions,
  asynchronous Hotwire state changes, and the final rendered/database outcome.
- Keep every scenario independently runnable with unique data.
- Keep the budget to one example per risk when practical.
- Record which boundaries remain real. Auth/session, Rails routing, database,
  views, and Hotwire should stay real; only external HTTP may be stubbed.

## GENERATE

- Write `require 'rails_helper'` and explicit `type: :system`.
- Place the file at `spec/system/<feature>/<risk>_spec.rb`.
- Execute the target spec through Cuprite while authoring it. Do not invent
  button text, labels, paths, or asynchronous behavior from memory.
- Prefer `click_button`, `fill_in`, `select`, and `choose`.
- After a Turbo/Stimulus action, wait with `have_content`, `have_button`,
  `have_field`, `have_select`, or `have_css`; never `sleep`.
- Use the seed's within-scoped attribute finder only for repeated controls that
  lack a usable label.
- Assert the business and database outcome that catches the named regression.
- Add a short provenance comment when useful:

```ruby
# Risk: test-plan.md #2 — submitted players are not silently dropped
# Seed: spec/system/game_sessions/player_fidelity_spec.rb
```

## No silent auto-healing

Capybara/Cuprite has no Playwright-style healer in this workflow. Maintenance
still has a strict boundary:

- If a label or selector changed but behavior is intact, update the interaction
  to the current accessible name, review it, and rerun the deliberate-break
  check.
- If business behavior changed, do not rewrite or weaken the assertion to make
  the spec green. Diagnose the regression.
- Never add pending/skip metadata to manufacture a passing phase.
- Never silently alter a risk-tied assertion during selector maintenance.

## Loop mapping

| Beat | Capybara path |
| --- | --- |
| PLAN | Explore views/Stimulus or drive Cuprite; model the flow on `player_fidelity_spec.rb` |
| GENERATE | Execute the flow and write one `type: :system` example from real behavior |
| REVIEW | Apply all five anti-pattern checks and re-prompt by name |
| VERIFY | Run `bin/rspec <path>`, deliberate-break the protected behavior, confirm red, then revert |

The prompt-template path is valid when the flow is already understood. It does
not relax seed, review, or verification requirements.
