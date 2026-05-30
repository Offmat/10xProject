---
bootstrapped_at: 2026-05-22T20:11:39Z
starter_id: rails
starter_name: Ruby on Rails
project_name: all-aboard
language_family: ruby
package_manager: bundle
cwd_strategy: subdir-then-move
bootstrapper_confidence: verified
phase_3_status: ok
audit_command: bundle audit check
---

## Hand-off

```yaml
starter_id: rails
package_manager: bundle
project_name: all-aboard
hints:
  language_family: ruby
  team_size: solo
  deployment_target: railway
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
```

### Why this stack

all-aBoard is a greenfield web-app with a three-week, after-hours MVP: email/password auth, friend circles, session logging with confirm/reject, in-app notifications, and filtered stats — all natural Rails territory. You chose Ruby and accepted the vetted default for web apps in that family: Ruby on Rails with PostgreSQL, which the bootstrapper has run end-to-end (verified confidence). Railway matches the starter's default deploy path; GitHub Actions with auto-deploy-on-merge keeps CI simple for a solo build. Auth is in scope per the PRD; payments, realtime websockets, AI/LLM features, and background-job queues are not required for v1.

## Pre-scaffold verification

| Signal      | Value   | Severity | Notes |
| ----------- | ------- | -------- | ----- |
| npm package | not run | n/a      | non-JS starter (`language_family: ruby`) |
| GitHub repo | not run | n/a      | `docs_url` is not a GitHub repository URL |

## Scaffold log

**Resolved invocation**: `rails new .bootstrap-scaffold --database postgresql --skip-bundle --skip-test`  
**Strategy**: subdir-then-move  
**Exit code**: 0  
**Files moved**: 90  
**Conflicts (.scaffold siblings)**: `.git.scaffold`  
**.gitignore handling**: moved silently  
**.bootstrap-scaffold cleanup**: deleted

## Post-scaffold audit

**Tool**: `bundle audit check`  
**Summary**: 0 CRITICAL, 0 HIGH, 0 MODERATE, 0 LOW  
**Direct vs transitive**: not distinguished by this tool  
**Exit code**: 0

#### CRITICAL findings

None.

#### HIGH findings

None.

#### MODERATE findings

None.

#### LOW / INFO findings

None.

**Raw output**:

```text
No vulnerabilities found
```

_Re-run after `bundle install` (2026-05-22). Initial bootstrap audit failed because gems were not yet installed._

## Hints recorded but not acted on

| Hint                    | Value |
| ----------------------- | ----- |
| bootstrapper_confidence | verified |
| quality_override        | false |
| path_taken              | standard |
| self_check_answers      | null |
| team_size               | solo |
| deployment_target       | railway |
| ci_provider             | github-actions |
| ci_default_flow         | auto-deploy-on-merge |
| has_auth                | true |
| has_payments            | false |
| has_realtime            | false |
| has_ai                  | false |
| has_background_jobs     | false |

## Next steps

Next: a future skill will set up agent context (CLAUDE.md, AGENTS.md). For now, your project is scaffolded and verified — happy hacking.

Useful manual steps in the meantime:
- `git init` (if you have not already) to start your own repo history.
- Review any `.scaffold` siblings the conflict policy created and decide which version of each file to keep.
- Address audit findings per your project's risk tolerance — the full breakdown is in this log.
