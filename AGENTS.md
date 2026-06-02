# Repository Guidelines

all-aBoard is a Rails 8.1 app (Ruby 3.4, PostgreSQL, Hotwire via importmap) for logging board-game sessions across friend groups. Product scope: @context/foundation/prd.md. Stack: @context/foundation/tech-stack.md. Deploy platform: @context/foundation/infrastructure.md (Railway).

## Hard rules

- Never write under `context/archive/` — archived changes are immutable.
- Do not commit `/.env*`, `vendor/bundle`, or `config/*.key`.
- Install gems through @bin/setup (`bundle` path `vendor/bundle`); prefer `bin/` wrappers over ad-hoc commands.
- PostgreSQL must be running before `bin/setup` or `db:*` (setup checks `pg_isready` when available).

## Project structure

- `app/` — MVC, services, jobs, mailers; MVP domains in @app/AGENTS.md.
- `config/` — app configuration; DB names `all_aboard_*` in @config/database.yml.
- `context/foundation/` — PRD, tech stack, infrastructure, lessons; edit in place per @context/foundation/README.md.
- `context/changes/` — in-flight change folders; finish with `/10x-archive`, not by editing `archive/` directly.
- `bin/` — `setup`, `ci`, `dev`, `rspec`, `rubocop`, `brakeman`, `bundler-audit`, `rails`.
- Bootstrap audit: @context/changes/bootstrap-verification/verification.md.

## Build, test, and development

- First-time / refresh: `bin/setup` — bundle, optional audit warning, `bin/rails db:prepare`, clears logs/tmp.
- DB reset: `bin/setup --reset`.
- Dev server: `bin/dev` or `bin/setup --run-server` (both start `bin/rails server`).
- Local CI: `bin/ci` runs @config/ci.rb (RuboCop, bundler-audit, importmap audit, Brakeman).
- Lint: `bin/rubocop` (Omakase: @.rubocop.yml).
- Tests: **RSpec** under `spec/` — `bin/rspec` or `bundle exec rspec` (see @spec/AGENTS.md). Prepare DB: `bin/rails db:test:prepare`. `rails/test_unit` remains disabled in @config/application.rb; do not use `bin/rails test`.

## Coding style

- Ruby 3.4.4 (@.ruby-version).
- Prefer single-quoted strings; use double quotes only when the string needs interpolation (`"#{…}"`) or embedded single quotes.
- @app/controllers/application_controller.rb restricts to modern browsers; change only if the product requires broader support.
- Auth convention: implement MVP auth with Rails built-ins, but keep naming and boundaries close to Devise patterns (`User`-centric model, `current_user` helpers, `authenticate_user!`-style guards, explicit sign-in/sign-out flow) to preserve an easy future migration path.

## Commits and CI

Recent history uses short imperative subjects and occasional `lesson N:` prefixes; no strict Conventional Commits rule yet. PRs to `main` must pass @.github/workflows/ci.yml: Brakeman, bundler-audit, importmap audit, RuboCop, RSpec (`spec/`). Local `bin/ci` runs the same checks via @config/ci.rb.

## Security

- Before merging security-sensitive work, run `bin/brakeman` and `bin/bundler-audit` locally (also in `bin/ci`).

## Architecture pointers

- MVP flows and business rules: @context/foundation/prd.md.
- Deploy platform and DB strategy: @context/foundation/infrastructure.md.
- 10x course skill router (Cursor): @.cursor/rules/10x-course.mdc — do not duplicate its tables here.
