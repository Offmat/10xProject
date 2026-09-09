# Spec Directory Guidelines

Application conventions: @app/AGENTS.md. Repo commands and CI: @AGENTS.md.

## Hard rules

- Spec files end with `_spec.rb`; place them under the folder that mirrors `app/` (e.g. `app/models/user.rb` → `spec/models/user_spec.rb`).
- Use `require 'rails_helper'` for anything loading Rails; `require 'spec_helper'` only for plain Ruby units with no Rails.
- Do not commit examples that depend on production data or real external APIs.
- Do not change application code solely to make specs pass. Prefer test-side fixes: stubs, helpers, factories, or `config/environments/test.rb`. If a production change is the only viable path, stop and ask how to proceed before editing `app/`.

## Layout

| Path | Use for |
|------|---------|
| `spec/models/` | ActiveRecord models, validations, scopes |
| `spec/requests/` | HTTP endpoints (preferred over controller specs for MVP) |
| `spec/system/` | Browser/system specs via Cuprite (explicit `type: :system`; require `rails_helper`) |
| `spec/services/unit/` | Single-class service behavior with stubs |
| `spec/services/integration/` | Multi-model flows (session log + confirm, etc.) |
| `spec/factories/` | FactoryBot definitions (`create(:user)`, etc.) |
| `spec/support/` | shared helpers — auto-loaded via @spec/rails_helper.rb |

## Authentication specs

- Request specs are the primary auth integration surface (`spec/requests/authentication_spec.rb`).
- Use helpers from @spec/support/authentication_helpers.rb: `sign_in_as`, `sign_out`, `register_user` (default password `'password'`).
- System specs: declare `type: :system` explicitly (file location does not infer type). `sign_in_as` injects the signed `session_id` cookie via Cuprite after a same-origin visit — do not fill the login form for auth setup.
- Rate-limit request specs only: stub `ActionController::Base.cache_store#increment` with a `MemoryStore` in that example group's `before` block (`config.cache_store` is `:null_store` in test). Do not stub globally.
- Assert externally visible behavior (redirects, flash, guards) — not cookie/session record internals unless testing the model layer.
- Auth audit expectations: prefer `expect(AuthAuditLogger).to receive(:log).with(hash_including(...))` before the request; service unit coverage lives in `spec/services/auth_audit_logger_spec.rb`.

## System / browser specs

- Driver: Cuprite via `spec/support/capybara.rb`. Declare `type: :system` and
  `require 'rails_helper'` (inference is off).
- Auth: `sign_in_as` injects the signed session cookie — never fill the login
  form for setup.
- Finders: prefer labels/buttons/text (`click_button`, `fill_in`, `select`,
  `choose`, `have_*` matchers). Never `sleep`. When a control has no usable
  label (e.g. repeated player rows), use attribute finders inside `within` —
  see the seed.
- Budget: one system example per named browser risk. Cookbook:
  `context/foundation/test-plan.md` §6.3–6.4. Seed exemplar:
  `spec/system/game_sessions/player_fidelity_spec.rb`. Agent workflow:
  `/10x-e2e-capybara`.
- Local Chrome/Chromium required; run `bin/rspec spec/system/`.

## Conventions

- Prefer FactoryBot (`create`, `build`) over YAML fixtures. Copy `describe`/`context`/`it` naming and matcher style from the nearest `_spec.rb` in the same folder. Run `bin/rubocop` on touched spec files.
- **Message expectations:** when verifying that code calls a collaborator, prefer setting the expectation before the action — `expect(Collaborator).to receive(:method).with(...)` then run the code under test. Use `allow` + `have_received` only when setup must run first (e.g. sign-in before asserting sign-out) or when one action needs several post-hoc assertions on the same mock.
- Service integration specs: assert DB side effects and authorization boundaries, not only return values.
- IDOR / ownership request examples: assert HTTP failure **and** that the target resource is unchanged after the attempt — see `context/foundation/test-plan.md` §6.5.
