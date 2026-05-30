---
project: all-aBoard
researched_at: 2026-05-29
recommended_platform: Railway
runner_up: Fly.io
context_type: mvp
tech_stack:
  language: Ruby
  framework: Rails 8.1
  runtime: Ruby 3.4 + PostgreSQL
---

## Recommendation

**Deploy on Railway.**

Railway fits a solo, after-hours Rails MVP that needs co-located PostgreSQL, fast iteration, and strong agent tooling. The interview pointed to co-located managed Postgres (not external Neon/Supabase), roughly equal cost/DX weighting, no existing platform familiarity, and possible future persistent processes — Railway's persistent services and one-click Postgres in the same project match those constraints better than edge/serverless platforms (Vercel, Netlify, Cloudflare), which were filtered out for lack of full Rails + Postgres support.

Railway wins on MCP integration (`railway mcp install`), GitHub-native deploys, and multi-MVP cost sharing (one Postgres service, multiple databases). Fly.io remains the runner-up: the Rails bootstrap default was Fly and the repo ships a production Dockerfile, but Railway's project canvas and agent-first CLI were chosen after the Railway anti-bias cross-check. `@context/foundation/tech-stack.md` records `deployment_target: railway`.

**Database:** stay on **PostgreSQL** (not SQLite). The app uses Rails 8 Solid Cache, Solid Queue, and Solid Cable with a four-database `config/database.yml` layout — all on one Railway Postgres service at MVP scale.

## Platform Comparison

Hard filters removed Vercel (experimental Rails, no co-located Postgres), Netlify (no persistent Ruby/Rails), and Cloudflare Workers (no Ruby runtime). Three container PaaS options were scored.

| Platform | CLI-first | Managed | Agent docs | Stable deploy API | MCP | Total |
|---|---|---|---|---|---|---|
| **Railway** | Pass | Pass | Partial | Pass | Pass | 4P / 1Partial |
| **Fly.io** | Pass | Pass | Partial | Pass | Partial | 4P / 1Partial |
| **Render** | Partial | Pass | Partial | Pass | Partial | 2P / 3Partial |

**Railway** — Best MCP and fastest co-located Postgres setup; usage-based billing less predictable than fixed tiers. Official docs state databases have no SLA and are not mission-critical by default ([use-cases](https://docs.railway.com/platform/use-cases)).

**Fly.io** — Matches existing Dockerfile and Rails-on-Fly docs; self-managed Fly Postgres ~$7–15/mo predictable; `flyctl mcp` experimental; no one-command rollback. Managed Postgres (MPG) starts at $38/mo (May 2026).

**Render** — Official Rails 8 deploy guide and predictable fixed pricing ($7 web + $7 DB starter); rollback is dashboard/API-first; Render MCP cannot trigger deploys or rollbacks programmatically.

### Shortlisted Platforms

#### 1. Railway (Recommended)

Strongest agent story: CLI-bundled MCP (`railway mcp`), `railway up`, `railway logs`, `railway connect`, project tokens for GitHub Actions. Postgres provisions in the same project with private networking (`postgres.railway.internal`). Multiple MVPs can share one Postgres service (separate databases) for ~$3–5/mo per extra web service instead of doubling DB cost.

Gap vs ideal: Railway's own docs warn default Postgres is for velocity, not mission-critical workloads — backups, restore drills, and optional PITR/HA are the operator's responsibility.

#### 2. Fly.io

Runner-up. Production Dockerfile and Thruster entrypoint already in repo; co-located Fly Postgres on private network; ~$14–20/mo for web + dev single-node DB. Better cost predictability per Machine. Weaker MCP maturity and manual image-based rollback (`fly releases --image` → `fly deploy --image`).

#### 3. Render

Third. Heroku-like Rails 8 blueprint (`render.yaml`), fixed-tier billing, dashboard rollback. CLI rollback not first-class; MCP limited. Good if predictable monthly bills matter more than agent automation.

## Anti-Bias Cross-Check: Railway

### Devil's Advocate — Weaknesses

1. **Railway documents that default Postgres is not mission-critical** — no SLA, not highly available; session and friend data need configured backups and tested restores.
2. **Usage billing can exceed Hobby's $5 credit** — Rails web + Postgres + Solid* activity often lands at $10–20/mo; egress and always-on RAM/CPU add up without a spend cap.
3. **`bin/docker-entrypoint` runs `db:prepare` before Puma** — deploy healthchecks fail if private networking to Postgres times out during startup (reported in community threads, Feb–Mar 2026).
4. **No single CLI command to roll back to deployment N** — prior-version recovery uses dashboard Redeploy on a specific deployment or deployment ID; agents need structured workflow docs.
5. **Four-database Solid* layout requires manual setup** — Railway provisions one Postgres; create `all_aboard_production_cache`, `_queue`, `_cable` and wire `database.yml` / env vars explicitly.
6. **`railway run` from a laptop cannot reach `postgres.railway.internal`** — migrations and DB tasks must run in-container or at deploy time, not via local CLI with prod env.

### Pre-Mortem — How This Could Fail

The team chose Railway for MCP speed and one-project Postgres. Week one deploys cleanly. Week four a deploy hangs on `db:prepare` while Postgres shows Online — private-network timeout between services; 40 minutes downtime until redeploy. Week eight the bill hits $22 on Hobby without a spend limit configured. Week sixteen a bad migration corrupts session data; backup restore exists but was never tested; PITR fork requires manual cutover (new sibling service, swap `DATABASE_URL`). They had read Railway's use-cases page but treated "not mission-critical" as marketing, not a checklist. A second MVP sharing the same Postgres cluster saved money until a runaway migration on the experiment affected connection pools for the primary app. The team concludes Railway accelerated shipping but did not replace DB ops discipline.

### Unknown Unknowns

- Railway may build with **Nixpacks** unless Dockerfile builder is configured — differs from the repo's Thruster + jemalloc Docker path; pin builder in `railway.toml` or service settings.
- **Solid Queue/Cache/Cable** share one Postgres instance's CPU/RAM meter — usage billing aggregates all write load.
- **Spend limits** can hard-stop services when cap is hit, not just warn.
- **Postgres HA conversion** drops connections and changes endpoints; in-project references auto-update, external clients do not.
- **Second MVP on shared Postgres** — cheap, but blast radius is one cluster; use separate DB users and names.
- **PITR window** starts only after enablement — cannot restore to before PITR was turned on ([PITR docs](https://docs.railway.com/volumes/point-in-time-recovery)).

## Operational Story

- **Preview deploys**: Create a `staging` environment in the Railway project (duplicate env or separate branch deploy). Railway supports per-environment services and variables; PR previews are not automatic like Vercel — use a staging service or ephemeral environment. Fork PRs need explicit project-token / workflow setup.
- **Secrets**: Service variables in Railway project/environment (encrypted at rest). Set `RAILS_MASTER_KEY` and DB URLs via dashboard or `railway variable set`. **Production deploy trigger:** Railway GitHub autodeploy on `main` with **Wait for CI** — not a GitHub Actions `railway up` workflow and **no** `RAILWAY_TOKEN` in GitHub Secrets for deploy (see @context/changes/deployment-plan/deployment-plan.md). Optional: project token + GHA only if you deliberately choose CLI deploy in CI instead of Railway webhooks. Rotation: update variable → redeploy. Agents may set non-production secrets via MCP/CLI; production credential rotation should stay human-approved.
- **Rollback**: Dashboard → Deployments → select prior successful deploy → **Redeploy**. CLI: `railway redeploy` redeploys *current* code; for prior artifact use deployment ID from `railway deployment list` and dashboard Redeploy. DB migrations do not roll back automatically — keep migrations backward-compatible or restore from backup/PITR fork.
- **Approval**: Human should approve production deploys, primary secret rotation, Postgres HA conversion, and PITR restore cutover. Agents may run `railway up` to staging, tail logs, and set non-prod variables unattended.
- **Logs**: `railway logs` (stream), `railway logs -n 100 --json`, `railway logs --build`, `railway logs <DEPLOYMENT_ID>`. MCP tools expose deploy and log operations. Metrics: `railway metrics`.

## Database Strategy

**Engine:** PostgreSQL on a single Railway Postgres service (co-located, private network).

| Database | Purpose |
|---|---|
| `railway` (Railway default via `${{Postgres.DATABASE_URL}}`) | Primary app data at MVP — Rails merges `DATABASE_URL` over `database.yml` names |
| `all_aboard_production_cache` | Solid Cache |
| `all_aboard_production_queue` | Solid Queue (future background jobs) |
| `all_aboard_production_cable` | Solid Cable (future WebSockets) |

`config/database.yml` lists `all_aboard_production` for the primary connection name; in production on Railway the effective database is whatever `DATABASE_URL` specifies (currently `railway`).

Create extra databases after Postgres provision:

```sql
CREATE DATABASE all_aboard_production_cache;
CREATE DATABASE all_aboard_production_queue;
CREATE DATABASE all_aboard_production_cable;
```

**MVP posture:** enable Railway **Backups**; run one restore drill before real users. Consider **PITR** before launch if session data loss is unacceptable. Railway HA is optional post-MVP ([PostgreSQL HA](https://docs.railway.com/databases/postgresql-ha)).

**Multi-MVP:** add another web service in the same project; reuse Postgres with a new database name — adds ~$3–5/mo usage, not a second DB machine.

**Not recommended for this repo:** SQLite on a volume (requires `pg` → `sqlite3` stack change); external Postgres (Neon/Supabase) breaks co-location preference unless latency is acceptable.

## Risk Register

| Risk | Source | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| Default Postgres not HA / no SLA | Research + Railway use-cases docs | M | H | Enable backups; test restore; document runbook; add PITR before launch |
| Deploy stuck at `db:prepare` (private network timeout) | Pre-mortem + community reports | M | H | Staging env; retry-tolerant healthcheck; monitor deploy logs; separate staging Postgres for experiments |
| Usage bill exceeds $5 Hobby credit | Devil's advocate | M | M | Set spend limit; check Usage weekly; budget $10–15/mo; scale-to-zero only for throwaway experiments |
| Rollback redeploys app but not schema | Unknown unknowns | M | H | Backward-compatible migrations; never drop columns in same deploy as code removal |
| Nixpacks ignores production Dockerfile | Unknown unknowns | M | M | Configure Dockerfile builder in Railway service settings or `railway.toml` |
| Shared Postgres blast radius (multi-MVP) | Devil's advocate | L | M | Separate DB names and users per app; no shared `DATABASE_URL` |
| Local `railway run` cannot reach internal Postgres | Unknown unknowns | M | L | Run migrations only in deploy entrypoint or `railway ssh` |
| Solid* load inflates single Postgres usage | Research finding | M | M | Monitor metrics; split to dedicated Postgres service if queue load grows |
| Thruster listens on wrong port vs Railway `PORT` | Deploy session (May 2026) | M | M | `bin/docker-entrypoint` sets `HTTP_PORT` from runtime `PORT`; do not use `${{PORT}}` in Railway service variables |

## Current deployment (May 2026)

Executed per @context/changes/deployment-plan/deployment-plan.md (Phases 0–3 complete; Phase 4 GitHub autodeploy pending):

| Item | Value |
|---|---|
| Railway project | `all-aboard` |
| Services | `Postgres`, `web` |
| Production URL | `https://web-production-8431bc.up.railway.app` |
| Health | `/up` → 200 |
| Builder | `railway.toml` → Dockerfile (Thruster + jemalloc) |
| Cable (production) | `solid_cable` — no Redis service |
| First deploy | `railway up` from linked repo (CLI); GitHub source not wired yet |
| Open ops | Postgres backups (P1.4), spend limit (P1.6), GitHub autodeploy + Wait for CI (Phase 4) |

## Getting Started

1. **Install Railway CLI** (macOS): `bash <(curl -fsSL https://railway.com/install.sh)` — verify with `railway --version`.

2. **Link project and add Postgres** (from repo root):
   ```bash
   railway login
   railway init --name all-aboard   # run railway link if init times out without linking
   railway add --database postgres --json
   railway add --service web --json
   ```

3. **Configure builder** — prefer the existing production Dockerfile (Ruby 3.4.4, Thruster, jemalloc) over Nixpacks defaults. In Railway service settings set builder to **Dockerfile**, or add `railway.toml`:
   ```toml
   [build]
   builder = "DOCKERFILE"
   dockerfilePath = "Dockerfile"
   ```

4. **Set secrets** (dashboard or CLI) — see variable table in @context/changes/deployment-plan/deployment-plan.md:
   ```bash
   railway service link web
   printf "%s" "$(cat config/master.key)" | railway variable set RAILS_MASTER_KEY --stdin --service web
   railway variable set RAILS_ENV=production --service web
   railway variable set DATABASE_URL='${{Postgres.DATABASE_URL}}' --service web
   # CACHE_DATABASE_URL, QUEUE_DATABASE_URL, CABLE_DATABASE_URL — see deployment plan
   ```
   Create cache/queue/cable databases (SQL above). Thruster: `bin/docker-entrypoint` exports `HTTP_PORT` from Railway's runtime `PORT`.

5. **Deploy and verify**:
   ```bash
   railway up --detach
   railway logs --build       # image build
   railway logs               # runtime; look for db:prepare
   curl -I https://<your-domain>/up
   ```

6. **Agent MCP** (optional): `railway mcp install` — configures local MCP for Cursor; use `--remote` for hosted OAuth MCP.

7. **GitHub autodeploy (Phase 4)** — in Railway dashboard: service `web` → connect repo `Offmat/10xProject`, branch `main`, enable autodeploy and **Wait for CI**. GitHub Actions (`.github/workflows/ci.yml`) runs quality gates only — **do not** add a GHA `railway up` deploy workflow or `RAILWAY_TOKEN` for production deploy.

**Notes:**

- `railway.toml` sets `preDeployCommand = "bin/rails db:prepare"`; `bin/docker-entrypoint` also runs `db:prepare` before `./bin/rails server` — both run today; consider removing entrypoint `db:prepare` once pre-deploy is stable.
- Start command stays `./bin/thrust ./bin/rails server` (Dockerfile `CMD`).

## Out of Scope

The following were not evaluated in this research:

- Docker image configuration (Dockerfile exists; deploy wiring only)
- Full CI/CD pipeline YAML for GitHub Actions
- Production-scale architecture (multi-region HA, DR, dedicated support tiers)
- Fly.io MPG, Render Enterprise, or hyperscaler RDS
