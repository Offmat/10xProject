# E2E Quality Rules

Use this block when generating or reviewing Capybara system specs for
all-aBoard.

## Rules block (Capybara + RSpec)

```text
# System Spec Rules

- Require 'rails_helper', declare type: :system, and place specs under spec/system/.
- Prefer click_button, fill_in, select, choose, have_button, have_field,
  have_content, and have_select.
- Never sleep. Wait for observable state with Capybara matchers, which retry up
  to Capybara.default_max_wait_time.
- Every example is independently runnable: create its own data, use unique
  identifiers, perform its own action and assertions, and leave isolation to
  Rails transactions where supported or clean up explicitly where required.
- Authenticate with sign_in_as from spec/support/authentication_helpers.rb.
  Never fill the login UI for setup.
- Prefer labels and visible button/link text. Sanctioned exception: when repeated
  nested fields have no usable label, use an attribute finder only inside a
  narrow within scope, for example find('[name$="[score]"]').
- Assert a rendered and/or database business outcome that fails if the named
  risk materializes.
```

## Governing rules

- **Start from a risk and the seed.** Read
  `context/foundation/test-plan.md` and
  `spec/system/game_sessions/player_fidelity_spec.rb`. Browser coverage is for
  risks crossing auth, routing, Hotwire, controller/service, and database
  boundaries, or behavior that exists only in rendered UI.
- **E2E does not mean zero mocking.** Keep the Rails session, routing, database,
  rendering, and Hotwire behavior real. Stub only expensive or
  non-deterministic external HTTP at the server boundary.
- **Name the example after the protected behavior.** Avoid generic names such as
  `it 'works'`.
- **Make the assertion risk-tied.** Ask: would this assertion fail if the
  test-plan risk occurred? A success flash alone is insufficient when the risk
  concerns persisted participants.
- **Keep the budget small.** Prefer one example per risk and one example per file
  when practical.

## Why these rules

Capybara's predicate and RSpec matchers synchronize by retrying until the
condition succeeds or `default_max_wait_time` expires. That is the governing
wait mechanism; `sleep` guesses at timing and creates flakes. The project's
live authority for form interaction, scoped nested-row fields, cookie auth, and
database assertions is
`spec/system/game_sessions/player_fidelity_spec.rb`.
