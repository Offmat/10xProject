# Repository Guidelines

all-aBoard is a Rails 8.1 app (Ruby 3.4, PostgreSQL, Hotwire via importmap) for logging board-game sessions across friend groups. Product scope: @context/foundation/prd.md. Stack and deploy intent: @context/foundation/tech-stack.md.

## Hard rules

- Never write under `context/archive/` — archived changes are immutable.
- Do not commit `/.env*`, `vendor/bundle`, or `config/*.key`.
- Install gems through @bin/setup (`bundle` path `vendor/bundle`); prefer `bin/` wrappers over ad-hoc commands.
- PostgreSQL must be running before `bin/setup` or `db:*` (setup checks `pg_isready` when available).

## Project structure

- `app/` — MVC, jobs, mailers.
- `config/` — app configuration; DB names `all_aboard_*` in @config/database.yml.
- `context/foundation/` — PRD, tech stack, lessons; edit in place per @context/foundation/README.md.
- `context/changes/` — in-flight change folders; finish with `/10x-archive`, not by editing `archive/` directly.
- `bin/` — `setup`, `ci`, `dev`, `rubocop`, `brakeman`, `bundler-audit`, `rails`.
- Bootstrap audit: @context/changes/bootstrap-verification/verification.md.

## Build, test, and development

- First-time / refresh: `bin/setup` — bundle, optional audit warning, `bin/rails db:prepare`, clears logs/tmp.
- DB reset: `bin/setup --reset`.
- Dev server: `bin/dev` or `bin/setup --run-server` (both start `bin/rails server`).
- Local CI: `bin/ci` runs @config/ci.rb (RuboCop, bundler-audit, importmap audit, Brakeman).
- Lint: `bin/rubocop` (Omakase: @.rubocop.yml).

Tests were skipped at bootstrap (`--skip-test` in verification log); no `test/` directory and `rails/test_unit` is disabled in @config/application.rb. Do not assume `bin/rails test` until a test stack is added.

## Coding style

- Ruby 3.4.4 (@.ruby-version).
- Module `BootstrapScaffold` in @config/application.rb is scaffold residue — rename when domain code should read `AllAboard`.
- @app/controllers/application_controller.rb restricts to modern browsers; change only if the product requires broader support.

## Commits and CI

Recent history uses short imperative subjects and occasional `lesson N:` prefixes; no strict Conventional Commits rule yet. PRs to `main` must pass @.github/workflows/ci.yml: Brakeman, bundler-audit, importmap audit, RuboCop. No test job in CI until tests exist.

## Security

- Before merging security-sensitive work, run `bin/brakeman` and `bin/bundler-audit` locally (also in `bin/ci`).

## Architecture pointers

- MVP flows (auth, sessions, friends, notifications): @context/foundation/prd.md.
- 10x course skill router (Cursor): @.cursor/rules/10x-course.mdc — do not duplicate its tables here.
