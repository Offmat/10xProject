# System Spec Generation Prompt Template

Use this template to generate one Rails system spec for one browser-level risk.
Leave this reference unchanged; fill a separate risk-specific prompt when the
workflow needs a durable prompt artifact.

The live seed and quality rules already define syntax and style. The prompt
adds only the risk, flow, and real-versus-mocked boundaries.

## Template

```text
Write a system spec for this risk from context/foundation/test-plan.md:
[risk id/title and short description]

Research anchor:
[test-plan phase, change plan phase, route/view/Stimulus flow]

Business scenario:
[one browser action sequence and the observable/database outcome that must hold]

Real boundaries (do not mock):
[signed session cookie via sign_in_as, Rails routing/controller/service,
PostgreSQL, rendered views, Turbo/Stimulus behavior]

Mocked boundaries:
[expensive or non-deterministic external HTTP, if any; otherwise "none"]

Create one RSpec example with explicit type: :system under
spec/system/<feature>/<risk>_spec.rb. Require 'rails_helper'.
Model it on spec/system/game_sessions/player_fidelity_spec.rb and follow
references/e2e-quality-rules.md. Authenticate with sign_in_as; do not use the
login UI. Assert the business or database outcome that fails if the risk
materializes. Explain in one sentence which regression the example catches.
```

## Worked example: all-aBoard player fidelity

```text
Write a system spec for these risks from context/foundation/test-plan.md:
Risks #1–#2: the dynamic multi-player form submits the wrong nested parameter
shape or silently drops a selected friend/guest participant.

Research anchor:
The game-session create flow, app/views/game_sessions/_form.html.erb,
app/views/game_sessions/_player_fields.html.erb, the nested-form Stimulus
controller, and spec/system/game_sessions/player_fidelity_spec.rb.

Business scenario:
A signed-in user selects a game, enters their score, adds one friend and one
guest through Stimulus rows, then logs the session. The resulting GameSession
must contain the creator, selected friend, and named guest with the submitted
scores and expected statuses.

Real boundaries (do not mock):
Authentication session cookie, Rails routes and controller/service,
PostgreSQL persistence, rendered form, and Stimulus row insertion.

Mocked boundaries:
None.

Write one RSpec system example under spec/system/game_sessions/ with explicit
type: :system and require 'rails_helper'. Use sign_in_as, Capybara label/button
APIs, matcher-based waits after each add-player action, and only the seed's
within-scoped attribute finder exception for unlabeled repeated controls.
Assert persisted participant identities and scores, not only the success flash.
```

Keep auth, session, database, routing, rendering, and Hotwire real. If the app
later gains an expensive external HTTP dependency, stub it where the Rails
server calls it; do not mock away the internal boundaries carrying the risk.
