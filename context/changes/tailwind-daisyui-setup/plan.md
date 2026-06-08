# Tailwind CSS + daisyUI Setup — Implementation Plan

## Overview

Integrate Tailwind CSS 4 and daisyUI 5 into the Rails 8.1 asset pipeline via `tailwindcss-rails`. Ship the "abyss" theme (deep dark green, teal, phosphorus), a base application layout shell (nav placeholder, flash partial, page container), and a restyled home page. Remove the existing hand-written CSS. Auth view restyling is deferred to S-01.

## Current State Analysis

- **CSS**: Single `app/assets/stylesheets/application.css` (65 lines) with CSS custom properties and BEM classes for the home page only.
- **Asset pipeline**: Propshaft serves files without preprocessing. No CSS build step exists.
- **JS**: importmap-rails + Hotwire (Turbo + Stimulus). No Node.js, no `package.json`.
- **Dev server**: `bin/dev` runs only `bin/rails server`. No `Procfile.dev`, no Foreman.
- **Views**: 8 ERB templates total. Auth views are unstyled (inline `style` attributes). No partials.
- **Production**: `Dockerfile` already runs `rails assets:precompile` (Propshaft fingerprinting today).

### Key Discoveries:

- `tailwindcss-rails` v4 bundles the standalone Tailwind CLI binary — Node.js is NOT needed at build time.
- daisyUI 5 is installed via npm as a `@plugin` directive resolved from `node_modules/`. This requires a one-time `npm install` for the package files but not a Node runtime during CSS compilation.
- The `tailwindcss:build` rake task is automatically hooked into `assets:precompile` and `test:prepare` by the gem.
- daisyUI 5 config lives in the CSS file itself (`@plugin "daisyui" { themes: abyss; }`) — no `tailwind.config.js`.

## Desired End State

After this plan is complete:
- Running `bin/dev` starts both the Rails server and the Tailwind CSS watcher via Foreman.
- All ERB views can use Tailwind utility classes and daisyUI semantic components (`btn`, `card`, `alert`, `navbar`, etc.).
- The app renders with the "abyss" theme by default (dark green/teal palette).
- The application layout includes a nav placeholder, a flash message partial using daisyUI `alert` classes, and a main content container.
- The home page is restyled with Tailwind/daisyUI classes (no custom CSS).
- `rails assets:precompile` produces fingerprinted Tailwind output in production.
- Local setup and CI explicitly install npm dependencies / satisfy Tailwind build prerequisites before specs run, and those updated paths pass cleanly.

## What We're NOT Doing

- Restyling auth views (sign in, sign up, password forms) — deferred to S-01.
- Adding dark/light mode toggle — single "abyss" theme only.
- Installing optional Tailwind plugins beyond daisyUI (e.g. `@tailwindcss/typography`, `@tailwindcss/forms`).
- Creating reusable ViewComponents or complex partial libraries.
- Styling mailer layouts (separate concern, low priority for MVP).
- Adding any custom Stimulus controllers for daisyUI interactive components.

## Implementation Approach

Use the `tailwindcss-rails` gem installer as the starting point, then layer daisyUI on top. The gem handles the standalone CLI binary, rake tasks, and asset pipeline wiring. daisyUI is added as an npm dependency (minimal `package.json`). Because views will depend on generated CSS, Phase 1 also brings `bin/setup`, local CI, and GitHub Actions into parity with the npm/Tailwind build requirements before the layout switches to `tailwind.css`.

---

## Phase 1: Tooling & Build Pipeline

### Overview

Install `tailwindcss-rails`, add daisyUI via npm, configure the CSS input file with `@plugin "daisyui"` and abyss theme, set up the Foreman-based dev server with a CSS watcher process, and update setup/CI paths so every environment can satisfy the new Tailwind build dependency before any views rely on it.

### Changes Required:

#### 1. Install tailwindcss-rails gem

**File**: `Gemfile`

**Intent**: Add the `tailwindcss-rails` gem which provides the standalone Tailwind CLI binary and rake tasks (`tailwindcss:build`, `tailwindcss:watch`).

**Contract**: New line in the main gem group: `gem 'tailwindcss-rails'`. Run `bundle install`.

#### 2. Run the tailwindcss:install generator

**Intent**: Execute `bin/rails tailwindcss:install` to scaffold the default Tailwind setup files. This creates the input CSS file, output directory, Procfile.dev, and updates bin/dev.

**Contract**: Generator creates:
- `app/assets/tailwind/application.css` (input file)
- `app/assets/builds/` directory (output destination)
- `Procfile.dev` with `web:` and `css:` entries
- Updates `bin/dev` to use Foreman/foreman-equivalent

If the generator's output conflicts with existing files, resolve manually per steps below.

#### 3. Add package.json with daisyUI

**File**: `package.json` (new, project root)

**Intent**: Declare daisyUI as an npm dependency so the standalone Tailwind CLI can resolve `@plugin "daisyui"` from `node_modules/`.

**Contract**: Minimal `package.json` with `daisyui` as a dependency. Run `npm install` to populate `node_modules/daisyui/`.

#### 4. Configure Tailwind CSS input with daisyUI + abyss theme

**File**: `app/assets/tailwind/application.css`

**Intent**: Configure the Tailwind build entry point to load daisyUI with the "abyss" theme as the single active theme.

**Contract**: The file imports Tailwind and enables daisyUI:

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: abyss --default;
}
```

#### 5. Configure Procfile.dev

**File**: `Procfile.dev`

**Intent**: Run the Rails server and Tailwind watcher concurrently in development.

**Contract**: Two processes:
- `web: bin/rails server`
- `css: bin/rails tailwindcss:watch`

#### 6. Update bin/dev to use Foreman

**File**: `bin/dev`

**Intent**: Replace the current single-command `bin/dev` with a Foreman launcher that reads `Procfile.dev`.

**Contract**: `bin/dev` executes `foreman start -f Procfile.dev` (or the gem's preferred runner). The `tailwindcss-rails` installer may handle this automatically.

#### 7. Add node_modules and builds to .gitignore

**File**: `.gitignore`

**Intent**: Exclude `node_modules/` and compiled CSS output from version control.

**Contract**: Append ignore rules that exclude `node_modules/` and generated files under `app/assets/builds/*` while preserving the placeholder keepfile (`!app/assets/builds/.keep`) so the directory remains tracked.

#### 8. Update Dockerfile for npm install

**File**: `Dockerfile`

**Intent**: Ensure the production Docker build installs npm dependencies before `assets:precompile` so daisyUI is available to the Tailwind CLI.

**Contract**: Install Node.js/npm in the Docker build stage, then add `npm install` (or `npm ci` if `package-lock.json` exists) before the existing `rails assets:precompile` step.

#### 9. Update bin/setup for npm-backed Tailwind builds

**File**: `bin/setup`

**Intent**: Keep fresh clones aligned with the new npm-backed Tailwind build before any view depends on `tailwind.css`.

**Contract**: Add `npm install` after `bundle install` and before database preparation so `bin/setup` produces a working dev/test environment with daisyUI available.

#### 10. Update local and GitHub CI paths for Tailwind prerequisites

**Files**: `config/ci.rb`, `.github/workflows/ci.yml`

**Intent**: Ensure local CI and GitHub Actions both install npm dependencies and satisfy the Tailwind build prerequisite before specs render layouts that reference `tailwind.css`.

**Contract**: `config/ci.rb` and the GitHub Actions test job are updated so the test path performs npm dependency installation and an explicit Tailwind build/setup step (directly or via `bin/setup`) before `bin/rspec`.

### Success Criteria:

#### Automated Verification:

- `bundle install` completes without errors
- `npm install` completes without errors
- `bin/rails tailwindcss:build` produces `app/assets/builds/tailwind.css` containing daisyUI classes
- `bin/dev` starts both web and css processes
- `bin/setup` completes on a fresh clone (or after removing `node_modules/`) with daisyUI available
- `bin/ci` passes with the new npm/Tailwind prerequisites in place
- `bin/rubocop` passes (no new violations)

#### Manual Verification:

- Visit `localhost:3000` — page loads without CSS errors in browser console
- Tailwind watcher rebuilds CSS on file save (add a utility class to a view, see it reflected)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 2: Layout Shell & Home Page

### Overview

Add a base application layout shell with daisyUI components (navbar placeholder, flash partial, page container), restyle the home page using Tailwind/daisyUI classes, and remove the old hand-written CSS file.

### Changes Required:

#### 1. Create flash messages partial

**File**: `app/views/shared/_flash.html.erb` (new)

**Intent**: Centralize flash message rendering using daisyUI `alert` component classes. Replace the inline `style: 'color:red/green'` pattern scattered across auth views.

**Contract**: Partial renders `flash[:notice]` and `flash[:alert]` using daisyUI `alert alert-success` / `alert alert-error` classes. Auto-dismissable via Turbo (no JS needed for MVP).

#### 2. Remove inline auth flash blocks

**Files**: `app/views/sessions/new.html.erb`, `app/views/users/new.html.erb`, `app/views/passwords/new.html.erb`, `app/views/passwords/edit.html.erb`

**Intent**: Prevent duplicate flash rendering once the shared flash partial is mounted in the application layout.

**Contract**: Remove the existing inline `flash[:alert]` / `flash[:notice]` blocks from the four auth templates while leaving their forms and validation/error rendering otherwise unchanged.

#### 3. Update application layout with shell

**File**: `app/views/layouts/application.html.erb`

**Intent**: Add the `data-theme="abyss"` attribute, a navbar placeholder, the flash partial, and a main content container. Wire the Tailwind build output stylesheet.

**Contract**:
- `<html data-theme="abyss">` sets the daisyUI theme
- `<body>` contains: navbar (minimal — app name + placeholder links), `render 'shared/flash'`, `<main>` container wrapping `yield`
- Stylesheet tag references the Tailwind build output (either via `stylesheet_link_tag "tailwind"` or the path the gem wires)
- Remove or replace the old `:app` stylesheet reference
- The layout owns the only `<main>` landmark for the page shell

#### 4. Restyle home page

**File**: `app/views/pages/home.html.erb`

**Intent**: Replace BEM classes with Tailwind utility classes and daisyUI components to prove the integration works end-to-end.

**Contract**: The home page renders with the abyss theme, using Tailwind layout utilities (flex, centering) and daisyUI text/badge classes. Replace the current root `<main>` with a `<section>` or `<div>` so the application layout remains the only page-level `<main>` landmark. No custom CSS classes remain.

#### 5. Remove old application.css

**File**: `app/assets/stylesheets/application.css`

**Intent**: Delete the hand-written CSS file since all styling now comes from Tailwind/daisyUI.

**Contract**: File is deleted. If Propshaft still needs the `stylesheets/` directory for other reasons (it doesn't — the Tailwind input lives in `app/assets/tailwind/`), verify no breakage.

### Success Criteria:

#### Automated Verification:

- `bin/rails tailwindcss:build` succeeds
- `bin/rspec` passes (no view-related test failures)
- `bin/rubocop` passes
- No references to old `.home*` CSS classes remain in any `.erb` file

#### Manual Verification:

- Home page renders correctly with abyss theme (dark background, teal/green accents)
- Flash messages display correctly (trigger via invalid form submission on an auth page)
- Navbar placeholder is visible and responsive
- Auth pages still render (unstyled but functional — no broken references)
- No 404s or asset errors in browser console

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 3: CI & Production Verification

### Overview

Verify the Docker production build works with the new Tailwind + daisyUI pipeline, ensure CI doesn't break, and confirm fresh-clone setup reproducibility.

### Changes Required:

#### 1. Verify Docker build

**File**: `Dockerfile`

**Intent**: Confirm that `docker build` succeeds with the npm install + assets:precompile steps producing correct output.

**Contract**: `docker build .` completes. The resulting image serves pages with Tailwind CSS applied. If Node.js is not in the base image, add it to the build stage only (multi-stage pattern).

#### 2. Verify bin/setup reproducibility on a clean dependency state

**File**: `bin/setup`

**Intent**: Confirm the Phase 1 `bin/setup` changes behave correctly for fresh clones and dependency reinstalls.

**Contract**: Simulate a fresh dependency state (remove `vendor/bundle` and `node_modules/`), run `bin/setup`, and confirm npm/Tailwind prerequisites are restored without additional script edits.

#### 3. Sync foundation/repo docs with new tooling baseline

**Files**: `AGENTS.md`, `context/foundation/tech-stack.md`

**Intent**: Keep persistent developer/agent documentation aligned with the new Tailwind + daisyUI + npm + Foreman workflow.

**Contract**: Update repo/foundation docs to reflect:
- `bin/dev` now runs both web and css watcher processes
- npm dependency install is required for daisyUI plugin resolution and should be part of local/CI expectations
- Tailwind/daisyUI are now part of the primary frontend stack

#### 4. Add note about S-01 auth view restyling

**File**: `context/foundation/roadmap.md`

**Intent**: Add explicit note to S-01 that auth views need restyling with daisyUI now that F-03 is complete.

**Contract**: Update S-01 entry's "Unknowns" or add a bullet under the slice noting: "Auth views use bare HTML from F-01 scaffold — restyle with daisyUI form/input/btn classes (F-03 provides the foundation)."

### Success Criteria:

#### Automated Verification:

- `docker build .` succeeds without errors
- `bin/setup` still completes on a fresh clone (simulated by removing `vendor/bundle` and `node_modules/`)
- `bin/ci` passes (RuboCop, bundler-audit, importmap audit, Brakeman)
- `bin/rspec` passes

#### Manual Verification:

- Docker container serves the home page with correct Tailwind styling
- No regressions in existing functionality (auth flows still work)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Testing Strategy

### Unit Tests:

- No new unit tests needed — this is infrastructure/styling only.

### Integration Tests:

- Existing RSpec request specs continue to pass (they test HTTP responses, not styling).
- `bin/rails tailwindcss:build` succeeds as part of `test:prepare` hook (automatic via gem).

### Manual Testing Steps:

1. Start `bin/dev` — both web and css processes start without errors.
2. Visit home page — renders with abyss theme styling.
3. Add a Tailwind class to any view, save — watcher rebuilds, browser reflects change.
4. Visit sign-in page — renders without errors (unstyled but functional).
5. Trigger a flash message — alert component displays correctly.
6. Run `docker build .` — completes without errors.
7. Run containerized app — serves styled pages.

## Performance Considerations

- Tailwind CSS output is purged by default (only classes used in views are included) — minimal CSS bundle size.
- daisyUI adds semantic classes on top of Tailwind utilities; unused component styles are tree-shaken.
- Standalone CLI build is fast (~30-50ms for incremental rebuilds during watch).
- Production build is minified automatically by the `tailwindcss:build` task.

## Migration Notes

- The old `application.css` is removed entirely — no incremental coexistence needed since auth views use inline styles (not CSS classes) and the home page is restyled in Phase 2.
- `node_modules/` is a new directory that must be in `.gitignore` and handled in Docker builds and `bin/setup`.
- The `Procfile.dev` changes how `bin/dev` works — developers must have `foreman` available (gem installs it as a dependency or the `tailwindcss-rails` installer uses a built-in alternative).

## References

- tailwindcss-rails gem: https://github.com/rails/tailwindcss-rails
- daisyUI 5 themes (abyss): https://daisyui.com/docs/themes/
- Roadmap F-03: `context/foundation/roadmap.md` (line 93–104)
- Existing layout: `app/views/layouts/application.html.erb`
- Existing CSS: `app/assets/stylesheets/application.css` (to be removed)

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Tooling & Build Pipeline

#### Automated

- [x] 1.1 `bundle install` completes without errors
- [x] 1.2 `npm install` completes without errors
- [x] 1.3 `bin/rails tailwindcss:build` produces output CSS with daisyUI classes
- [x] 1.4 `bin/dev` starts both web and css processes
- [x] 1.5 `bin/setup` completes with daisyUI available after reinstalling dependencies
- [x] 1.6 `bin/ci` passes with the new npm/Tailwind prerequisites in place
- [x] 1.7 `bin/rubocop` passes

#### Manual

- [x] 1.8 Page loads without CSS errors in browser console
- [x] 1.9 Tailwind watcher rebuilds CSS on file save

### Phase 2: Layout Shell & Home Page

#### Automated

- [x] 2.1 `bin/rails tailwindcss:build` succeeds
- [x] 2.2 `bin/rspec` passes
- [x] 2.3 `bin/rubocop` passes
- [x] 2.4 No references to old `.home*` CSS classes in any `.erb` file

#### Manual

- [x] 2.5 Home page renders with abyss theme
- [x] 2.6 Flash messages display as daisyUI alerts
- [x] 2.7 Navbar placeholder is visible and responsive
- [x] 2.8 Auth pages render without errors (unstyled but functional)
- [x] 2.9 No asset errors in browser console

### Phase 3: CI & Production Verification

#### Automated

- [x] 3.1 `docker build .` succeeds
- [x] 3.2 `bin/setup` completes on fresh clone
- [x] 3.3 `bin/ci` passes
- [x] 3.4 `bin/rspec` passes

#### Manual

- [x] 3.5 Docker container serves home page with Tailwind styling
- [x] 3.6 No regressions in auth flows
