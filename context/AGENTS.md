# Context Directory Guidelines

See @AGENTS.md at the repo root for repo-wide rules.

## Hard rules

- `context/archive/` is immutable.
- Do not put change-scoped artifacts (plans, research, reviews) in `context/foundation/`; use `context/changes/<change-id>/` instead.
- Foundation update convention: @context/foundation/README.md.

## Folders

- `context/foundation/` — cross-change docs (PRD, tech stack, infrastructure, lessons). Superseded foundation docs move to `foundation/archive/YYYY-MM-DD-<name>.md`, not `context/archive/`. Conventions: @context/foundation/README.md.
- `context/changes/` — one folder per in-flight change; identity in `change.md`. Created via course `/10x-new`; finish/archive workflow: @AGENTS.md.
- `context/archive/` — read-only completed changes from `changes/`; write rules: @AGENTS.md.

## Working on a change

1. Keep all artifacts for that change inside `context/changes/<change-id>/`.
2. When the change ships, archive with `/10x-archive` (moves the folder to `context/archive/`).
3. Edit `context/foundation/` only for repo-wide facts that stay true after archive (e.g. new gem in @context/foundation/tech-stack.md, PRD guardrail change). Keep change-local notes inside the change folder or archived copy — do not promote them to foundation.
