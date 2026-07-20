# App Directory Guidelines

Repo-wide rules: @AGENTS.md. Spec layout and auth test helpers: @spec/AGENTS.md.

## Authentication (F-01)

MVP auth uses Rails built-in patterns with Devise-adjacent naming so a future gem swap stays incremental.

### Boundaries

| Concern | Location |
|---------|----------|
| Default route protection, `current_user`, session cookie | @app/controllers/concerns/authentication.rb |
| Sign-in / sign-out | @app/controllers/sessions_controller.rb |
| Password reset | @app/controllers/passwords_controller.rb |
| Registration | @app/controllers/users_controller.rb |
| Public home page (explicit allowlist) | @app/controllers/pages_controller.rb |
| User credentials + email normalization | @app/models/user.rb |
| DB-backed session records | @app/models/session.rb, @app/models/current.rb |
| Structured auth audit lines | @app/services/auth_audit_logger.rb |

### Conventions

- App-facing parameter is `email` (normalized on `User` before save).
- Controllers include `Authentication`; use `allow_unauthenticated_access` only on intentionally public actions.
- `authenticate_user!` is available as a class-method alias for `require_authentication` when an action needs explicit protection beyond the default.
- Do not read `cookies[:session_id]` or `Current` from domain code outside auth plumbing — use `current_user` in controllers and pass identity into services explicitly.
- Rate limiting on session/password `create` uses Rails `rate_limit`; request specs that assert throttling stub cache `increment` only in that describe block (see `spec/requests/authentication_spec.rb`).

### Routes

`resource :session`, `resources :passwords`, `resources :users` (new/create only) — see @config/routes.rb.

## Services convention

All services live under `app/services/`, namespaced by domain (e.g. `GameCatalog::ImportService` in `app/services/game_catalog/`). Flat files for cross-cutting utilities (e.g. @app/services/auth_audit_logger.rb).

- **Orchestrator / business-action classes** expose a single public `.call` class method. Name the class after the action: `ImportService`, `CreateSession`.
- **Infrastructure / utility classes** (HTTP clients, loggers, mappers) may use a descriptive method name (`.fetch`, `.log`) when `.call` would be less clear.
- One public method per class. Keep internals private.
- When a class stores instance variables, add a private `attr_reader` and use the reader instead of `@`-prefixed access throughout the class.
- Do not add an `ApplicationService` base class until there are 5+ services sharing the same delegation boilerplate.

## Views convention

- **Do not query the database from views or layouts.** Controllers (or helpers that only read already-assigned ivars) own data loading. Views render assigned instance variables only.
- Shared layout data that every authenticated page needs (e.g. nav badge counts) is set via a `before_action` on `ApplicationController`, not inline ActiveRecord calls in `application.html.erb`.
