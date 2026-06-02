# Spec Directory Guidelines

Application conventions: @app/AGENTS.md. Repo commands and CI: @AGENTS.md.

## Hard rules

- Spec files end with `_spec.rb`; place them under the folder that mirrors `app/` (e.g. `app/models/user.rb` → `spec/models/user_spec.rb`).
- Use `require 'rails_helper'` for anything loading Rails; `require 'spec_helper'` only for plain Ruby units with no Rails.
- Do not commit examples that depend on production data or real external APIs.

## Layout

| Path | Use for |
|------|---------|
| `spec/models/` | ActiveRecord models, validations, scopes |
| `spec/requests/` | HTTP endpoints (preferred over controller specs for MVP) |
| `spec/services/unit/` | Single-class service behavior with stubs |
| `spec/services/integration/` | Multi-model flows (session log + confirm, etc.) |
| `spec/factories/` | FactoryBot definitions (`create(:user)`, etc.) |
| `spec/support/` | shared helpers — auto-loaded via @spec/rails_helper.rb |

## Conventions

- Prefer FactoryBot (`create`, `build`) over YAML fixtures. Copy `describe`/`context`/`it` naming and matcher style from the nearest `_spec.rb` in the same folder. Run `bin/rubocop` on touched spec files.
- Service integration specs: assert DB side effects and authorization boundaries, not only return values.
