# Tailwind CSS + daisyUI Setup — Plan Brief

> Full plan: `context/changes/tailwind-daisyui-setup/plan.md`

## What & Why

Integrate Tailwind CSS 4 and daisyUI 5 into the Rails 8.1 asset pipeline so that all future vertical slices (S-01 through S-04) can use semantic component classes (`btn`, `card`, `alert`, `navbar`, etc.) and utility-first styling without hand-writing CSS. This is foundation infrastructure (F-03) with no prerequisites — it unblocks polished UI in every subsequent slice.

## Starting Point

The app uses Propshaft with a single 65-line hand-written `application.css` (BEM classes for the home page). No CSS build step, no Node.js, no `Procfile.dev`. Auth views are unstyled (inline `style` attributes from the F-01 scaffold). `bin/dev` runs only the Rails server.

## Desired End State

Running `bin/dev` starts both the Rails server and a Tailwind CSS watcher. The app renders with daisyUI's "abyss" theme (deep dark green/teal). The layout includes a navbar placeholder, flash alerts using daisyUI components, and a container wrapper. Any ERB view can use Tailwind utilities and daisyUI classes immediately. Production Docker builds produce minified, purged CSS automatically.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) |
|----------|--------|-------------------|
| CSS framework | Tailwind CSS 4 + daisyUI 5 | Utility-first with semantic components — fast to build polished UI without custom CSS. |
| Integration method | `tailwindcss-rails` gem (standalone CLI) | No Node.js runtime needed at build time; gem bundles the binary and wires rake tasks. |
| Theme | daisyUI "abyss" (single, no toggle) | Deep dark green/teal palette; ships as single theme — dark mode toggle out of scope for MVP. |
| daisyUI installation | npm `package.json` + `node_modules/` | Required for `@plugin "daisyui"` resolution; minimal footprint (no full Node toolchain in dev). |
| Old CSS | Remove entirely | Only 65 lines, home page only — cleaner to replace than coexist. |
| Auth view restyling | Deferred to S-01 | F-03 provides the foundation; S-01 owns auth UX polish as a user-visible slice. |
| Layout shell | Ship with F-03 | Nav placeholder + flash partial + container give every subsequent slice a consistent frame to build in. |

## Scope

**In scope:**
- `tailwindcss-rails` gem + daisyUI npm package
- Tailwind CSS input file with `@plugin "daisyui" { themes: abyss; }`
- `Procfile.dev` + Foreman-based `bin/dev` (web + css watcher)
- Base layout shell (navbar, flash partial, main container)
- Home page restyled with Tailwind/daisyUI
- Docker build updated for npm install
- `.gitignore` for `node_modules/` and `app/assets/builds/`

**Out of scope:**
- Auth view restyling (S-01)
- Dark/light mode toggle
- Additional Tailwind plugins (@tailwindcss/typography, @tailwindcss/forms)
- ViewComponents or complex partial libraries
- Mailer layout styling
- Custom Stimulus controllers for daisyUI interactive components

## Architecture / Approach

```
app/assets/tailwind/application.css  →  [Tailwind CLI standalone]  →  app/assets/builds/tailwind.css
        ↑                                        ↑                              ↓
  @plugin "daisyui"                    node_modules/daisyui/           Propshaft serves to browser
```

`tailwindcss-rails` hooks `tailwindcss:build` into `assets:precompile` (production) and `test:prepare` (specs). In development, `Procfile.dev` runs `tailwindcss:watch` alongside the Rails server.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|-----------------|----------|
| 1. Tooling & Build Pipeline | Gem, npm, CSS input, Procfile, bin/dev, .gitignore, Dockerfile | Node.js availability in Docker build stage |
| 2. Layout Shell & Home Page | Navbar, flash partial, container, restyled home, old CSS removed | Visual regression on home page (low — only 1 styled page) |
| 3. CI & Production Verification | Docker build, bin/setup, CI pass, S-01 note | Docker image size increase from Node in build stage |

**Prerequisites:** None (F-03 is independent of all other slices).
**Estimated effort:** ~1 session across 3 phases.

## Open Risks & Assumptions

- Assumes `tailwindcss-rails` latest version supports Tailwind v4 with `@plugin` directives (confirmed via docs).
- Docker base image may need Node.js added to the build stage for `npm install`; this adds image build time but not runtime size (multi-stage).
- `foreman` gem (or equivalent) must be available for `bin/dev` — the `tailwindcss-rails` installer typically handles this.

## Success Criteria (Summary)

- `bin/dev` starts both processes and the home page renders with the abyss theme.
- Any view can use daisyUI classes (e.g. `btn btn-primary`) and they render correctly.
- `docker build .` and `bin/ci` pass without modification to existing quality gates.
