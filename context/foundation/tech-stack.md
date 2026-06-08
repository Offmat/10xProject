---
starter_id: rails
package_manager: bundle
project_name: all-aboard
hints:
  language_family: ruby
  team_size: solo
  deployment_target: railway
  ci_provider: github-actions
  ci_default_flow: railway-autodeploy-on-merge-with-gha-quality-gates
  bootstrapper_confidence: verified
  path_taken: standard
  quality_override: false
  self_check_answers: null
  has_auth: true
  has_payments: false
  has_realtime: false
  has_ai: false
  has_background_jobs: false
---

## Why this stack

all-aBoard is a greenfield web-app with a three-week, after-hours MVP: email/password auth, friend circles, session logging with confirm/reject, in-app notifications, and filtered stats — all natural Rails territory. You chose Ruby and accepted the vetted default for web apps in that family: Ruby on Rails with PostgreSQL, which the bootstrapper has run end-to-end (verified confidence). Deploy target is **Railway** with co-located managed PostgreSQL (see @context/foundation/infrastructure.md); **Railway autodeploy on merge to `main`** with GitHub Actions quality gates (Wait for CI) — not a GHA deploy workflow. First production deploy validated via `railway up` (Phase 4 GitHub wiring still pending). Auth is in scope per the PRD; payments, realtime websockets, AI/LLM features, and background-job queues are not required for v1.

## Auth implementation convention

Use Rails built-in authentication for MVP, but keep auth code close to Devise-style conventions so a future migration stays low-friction.

- Keep `User` as the canonical auth model and prefer common naming (`email` in app-level APIs, normalized before persistence).
- Keep controller/session boundaries explicit (`current_user`, `authenticate_user!`-style guard methods, sign-in/sign-out helpers).
- Isolate auth plumbing in dedicated concerns/services; avoid spreading direct session internals across domain code.
- Keep request specs centered on externally visible auth behavior (login/logout/guards), not private implementation details.
- Avoid introducing custom auth primitives that diverge from mainstream Rails/Devise patterns unless required by product scope.

Agent-oriented file map (F-01 scaffold): @app/AGENTS.md. Request-spec helpers: @spec/support/authentication_helpers.rb (`sign_in_as`, `sign_out`, `register_user`). Rate-limit specs stub cache increment only in their example group.

## Frontend (F-03)

- **CSS build:** Tailwind CSS 4 via `tailwindcss-rails` (standalone CLI, no Node runtime at compile time). Input: `app/assets/tailwind/application.css`; output: `app/assets/builds/tailwind.css`.
- **daisyUI:** npm dependency (`daisyui` in `package.json`); configured via `@plugin "daisyui"` in the Tailwind input file. Theme: `abyss` (default).
- **Dev workflow:** `bin/dev` runs Foreman with `Procfile.dev` (web + `tailwindcss:watch`). Run `npm install` after clone (`bin/setup` handles this).
- **CI/production:** GitHub Actions and `bin/setup` install npm deps and run `bin/rails tailwindcss:build` before specs; Docker build runs `npm ci` before `assets:precompile`.
