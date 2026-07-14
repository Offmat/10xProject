# all-aBoard

Rails app for logging board-game sessions across friend groups.

## Ruby version

Ruby **3.4.4** (see `.ruby-version`). Use a version manager such as rbenv or asdf.

## System dependencies

- **PostgreSQL** — must be running locally before setup (`pg_isready` is checked by `bin/setup`)
- **Node.js + npm** — required for Tailwind CSS / daisyUI plugin resolution
- **Bundler** — gems install to `vendor/bundle`

## Configuration

First-time setup from the repo root:

```bash
bin/setup
```

This installs gems, runs `npm install`, builds Tailwind CSS, and runs `bin/rails db:prepare`.

Rails credentials: `config/master.key` must be present locally (not committed). Production uses `RAILS_MASTER_KEY` on Railway.

To reset the local database:

```bash
bin/setup --reset
```

## Database creation

Local databases (from `config/database.yml`):

| Environment | Database |
|---|---|
| development | `all_aboard_development` |
| test | `all_aboard_test` |

`bin/setup` runs `db:prepare`, which creates and migrates databases as needed.

Production uses four PostgreSQL databases on a single Railway Postgres service (primary, cache, queue, cable). See [Production database (Railway)](#production-database-railway) below.

## How to run the test suite

```bash
bin/rspec
```

Prepare the test database if needed:

```bash
bin/rails db:test:prepare
```

Run the full local CI pipeline (RuboCop, security audits, RSpec):

```bash
bin/ci
```

## Services

Background infrastructure runs on PostgreSQL via Rails 8 Solid adapters (no Redis):

- **Solid Cache** — database-backed caching
- **Solid Queue** — background jobs
- **Solid Cable** — Action Cable / WebSockets

Locally these share your development PostgreSQL instance. In production they use separate databases on the Railway Postgres service.

## Deployment

Deployed on [Railway](https://railway.com) (project **all-aboard**, services **Postgres** + **web**).

- Production URL: `https://web-production-8431bc.up.railway.app`
- Health check: `/up`
- Deploys via Railway GitHub autodeploy on `main` (with Wait for CI)
- Migrations run on deploy via `preDeployCommand` and `bin/docker-entrypoint`

Full infrastructure notes: [context/foundation/infrastructure.md](context/foundation/infrastructure.md)

## Production database (Railway)

The Railway project is **all-aboard** with two services: **Postgres** and **web**. Production uses four PostgreSQL databases on the same Postgres service:

| Database | Purpose |
|---|---|
| `railway` | Primary app data (`DATABASE_URL`) |
| `all_aboard_production_cache` | Solid Cache |
| `all_aboard_production_queue` | Solid Queue |
| `all_aboard_production_cable` | Solid Cable |

### Prerequisites

- [Railway CLI](https://docs.railway.com/develop/cli) installed and authenticated
- Local `psql` client for CLI access (`psql --version`)
- Repo linked to the Railway project:

```bash
railway login
railway link --project all-aboard
```

### Option 1: `railway connect` (recommended for SQL)

Opens an interactive `psql` session against the production Postgres service:

```bash
railway connect postgres
```

Useful commands once connected:

```sql
\l                                     -- list databases
\c railway                             -- primary app DB
\c all_aboard_production_cache         -- Solid Cache
\c all_aboard_production_queue         -- Solid Queue
\c all_aboard_production_cable         -- Solid Cable
```

**Requirements:** the Postgres service must have **TCP Proxy** enabled (Railway enables this by default for databases). If `connect` fails, check Postgres → Settings → Networking → TCP Proxy in the Railway dashboard.

### Option 2: Railway dashboard

1. Open the [Railway dashboard](https://railway.com) → project **all-aboard** → **Postgres** service.
2. Use the **Data** tab to run SQL in the browser.

### Option 3: GUI client (TablePlus, pgAdmin, DBeaver)

1. In Postgres → **Variables**, copy `DATABASE_PUBLIC_URL`.
2. Connect with your GUI client using that URL.

```bash
psql "$DATABASE_PUBLIC_URL"
```

### Option 4: Rails console (in-container)

The app reaches Postgres over Railway's private network (`postgres.railway.internal`). That hostname is only available **inside** Railway containers — not from your laptop.

For Rails console or manual migration checks against production:

```bash
railway service link web
railway ssh
```

Then inside the container:

```bash
bin/rails console
bin/rails db:migrate:status
```

**Do not** run production DB tasks with `railway run` from your laptop — local `railway run` injects production env vars but cannot reach the internal Postgres hostname.

Migrations normally run automatically on deploy via `preDeployCommand` and `bin/docker-entrypoint` (`db:prepare`).

### Quick reference

| Goal | Command |
|---|---|
| Run SQL / inspect tables | `railway connect postgres` or dashboard **Data** tab |
| GUI client | `DATABASE_PUBLIC_URL` from Postgres variables |
| Rails console | `railway ssh` → `bin/rails console` |
| Manual migration | `railway ssh` → `bin/rails db:migrate` |

### Security

`DATABASE_PUBLIC_URL` exposes Postgres to the internet (with authentication). Keep credentials private and disable TCP proxy if you only need in-project access via SSH.

## Development server

```bash
bin/dev
```

Runs Rails and the Tailwind CSS watcher via Foreman. App is available at `http://localhost:3000`.

## Further reading

- [AGENTS.md](AGENTS.md) — contributor and agent guidelines
- [context/foundation/prd.md](context/foundation/prd.md) — product scope
