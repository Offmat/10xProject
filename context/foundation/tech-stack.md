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
