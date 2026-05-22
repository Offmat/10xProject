---
starter_id: rails
package_manager: bundle
project_name: all-aboard
hints:
  language_family: ruby
  team_size: solo
  deployment_target: fly
  ci_provider: github-actions
  ci_default_flow: auto-deploy-on-merge
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

all-aBoard is a greenfield web-app with a three-week, after-hours MVP: email/password auth, friend circles, session logging with confirm/reject, in-app notifications, and filtered stats — all natural Rails territory. You chose Ruby and accepted the vetted default for web apps in that family: Ruby on Rails with PostgreSQL, which the bootstrapper has run end-to-end (verified confidence). Fly matches the starter’s default deploy path; GitHub Actions with auto-deploy-on-merge keeps CI simple for a solo build. Auth is in scope per the PRD; payments, realtime websockets, AI/LLM features, and background-job queues are not required for v1.
