# Interactive Rails Forms (Hotwire / Stimulus / Turbo)

Living playbook for interactive forms on this stack. Use it for any form that adds conditional branches, dynamic nested rows, multi-instance pages, or Turbo re-renders — not only session logging.

**Core idea:** Stimulus is glue. Interactive forms are mostly a server-rendering problem. Prefer HTML the server already knows how to re-render (including on 422) over client-owned state and client-built markup.

Evidence and longer worked notes: `context/changes/rails-interactive-forms-guide/research.md` (moves under `context/archive/` when that change is archived).

---

## Ten principles

1. **The DOM is the source of truth.** Controllers are discardable; attributes survive Turbo Drive, Frames, Streams, and reconnects.
2. **Escalate, don't start at the top.** Ask whether JavaScript is needed at all, then whether the server knows something the client doesn't, before choosing a round-trip or a controller.
3. **One responsibility per controller, composed on one element.** `data-controller="form nested-form auto-submit"` is idiomatic; a mega feature controller is not.
4. **Scope to the controller element.** Prefer `this.element`, targets, and `event.target.closest(...)`. Never use `document.querySelector` for anything a form owns.
5. **A repeated section needs its own controller identity.** Stimulus scopes are exclusive by identifier. Rows must use a *different* identifier from the container (or the container must use `closest()` and never nest the same identifier).
6. **Never guess a data shape.** Declare `static values` with types; treat `dataset` as strings; use `event.params` for coerced button data; validate fetch payloads at the boundary.
7. **Conditional fields need `disabled`, not just `hidden`.** Hidden-but-enabled inputs still submit. Prefer `<fieldset disabled>` so the inactive branch leaves the payload and the tab order.
8. **Unique numeric indices are a correctness requirement.** Duplicate indices silently drop rows in Rails nested params. Bare `Date.now()` can collide; use a monotonic counter seeded from `Date.now()`. Indices must match `/\A-?\d+\z/` so strong params treat children as an array of hashes.
9. **Design for reconnection.** `connect()` must be idempotent; release acquisitions in `disconnect()`; prefer `valueChanged` / `targetConnected` over one-shot `connect()` loops.
10. **Test the wiring where it fails.** Assert params and `data-*` wiring in request specs; system-test interactive happy paths in a real browser; unit-test only logic extracted from the controller.

---

## Escalation ladder

```text
HTML → CSS → Turbo Frame → Turbo Stream → Stimulus (attribute toggling) → Stimulus (fetch + client render)
```

Pick the leftmost option that solves the problem.

| Question | Prefer |
|---|---|
| Does the browser already do it (`<details>`, `<dialog>`, `popover`, `:has()`, native validation)? | HTML / CSS; add Stimulus only for the delta |
| Does the server know something the client doesn't (options, policy, lookups)? | Turbo Frame / Stream / full re-render |
| Purely local UI with no new server facts? | Small Stimulus attribute / class toggle |
| About to build HTML from data in JS? | Stop — use `<template>` clone or server HTML |

Justify any rung above "server renders it" in the change plan.

---

## Who owns what

| Concern | Owner |
|---|---|
| Domain truth, validation, what the form looks like in each state (including 422) | Server |
| Field names, ids, strong params, params shape | Rails (`form_with`, `fields_for`, `field_id` / `field_name`) |
| Navigation and partial replacement | Turbo (Drive, Frame, Stream, morph) |
| Local ephemeral behaviour on HTML it did not create | Stimulus |

### State-ownership table

| State | Owner | Mechanism |
|---|---|---|
| Domain data | Server / DB | Rendered HTML + submitted params |
| Whether a row is persisted | Server | `id` field and/or `data-persisted` |
| Active conditional branch | Server on render; DOM after interaction | `checked` + `disabled` fieldset |
| Controller configuration (URL, limit, key) | Server → DOM | `static values` |
| Transient UI (open/closed, tab) | DOM | values, classes, or native attributes |
| Next row index | DOM / controller private field | Monotonic numeric counter |
| Timers, observers, third-party widgets | Controller instance | Private fields; release in `disconnect()` |
| Shareable UI state (filters) | URL | Query params; server re-renders |

**One owner per fact.** If the same truth lives in an instance field *and* the DOM, delete one copy.

---

## Controller essentials

- **Size:** Prefer a lopsided distribution of small controllers. A large controller is sometimes correct; a codebase where *every* controller is large is usually over-cliented.
- **Compose:** Multiple identifiers on one element; callbacks/actions fire in attribute order.
- **Name for behaviour** (`nested-form`, `auto-submit`, `toggle-class`), not for the page (`session-form`, `checkout`). Domain names are fine when the behaviour *is* domain-specific.
- **Lifecycle:** Prefer `[name]TargetConnected` / `[name]ValueChanged` for derived UI. Instances are reused across reconnect; `connect()` may run many times — keep it idempotent. Prefer `data-action` over manual listeners; pair every manual attach with `disconnect()`.
- **Extract** non-DOM algorithms to plain modules when they have their own vocabulary; don't invent a base controller early.
- **Submit:** Always `requestSubmit()`, never `submit()` (the latter skips validation and Turbo).

Canonical state shape (when state has more than one writer or must re-derive after external updates):

```javascript
export default class extends Controller {
  static values = { open: Boolean }
  static targets = [ 'panel' ]
  static classes = [ 'hidden' ]

  toggle() { this.openValue = !this.openValue }

  openValueChanged() {
    this.panelTarget.classList.toggle(this.hiddenClass, !this.openValue)
  }
}
```

For one-writer toggles, doing the work in the action handler (as many production apps do) is also fine — avoid duplicating truth either way.

---

## HTML architecture essentials

- **Scopes are exclusive per identifier.** An outer `list` cannot see targets inside a nested `list`, and bubbling actions from the inner never reach the outer. Different identifiers for container vs row.
- **Values and classes** must sit on the same element as `data-controller`.
- **Targets:** declare `static targets`; use `has*Target` when optional; `*Target` throws if missing.
- **Values:** typed `static values` — never parse configuration out of `dataset` by hand.
- **Classes:** keep Tailwind/daisyUI names in HTML via `static classes`.
- **Outlets:** rare; selector is global — poor fit for repeated rows. Prefer shared DOM attributes or `this.dispatch` events.
- **No fragile selectors:** targets and owned `data-*` hooks, not design classes or `nth-child`.

---

## Condensed pattern catalogue

### Radio / conditional branches

Server renders the active branch's `disabled` state. A `change` action toggles `disabled` on the inactive `<fieldset>`; CSS can derive visibility (`disabled:hidden`). Keep `required` in sync with visibility. Group radios in `<fieldset>` + `<legend>` (legend first child); use `aria-controls` on the trigger.

Mistake: `hidden` / `display:none` alone while inputs stay enabled.

### Checkboxes

Same disable/hide discipline. Scope "check all" to `this.element`. Remember Rails' hidden `0` companion field when disabling/removing checkbox inputs.

### Dependent options (server knows the list)

Turbo Frame around the dependent field; drive with `change` → hidden GET button (`formmethod` / `formaction`) so params re-encode. Prefer Frames over JSON+`<option>` building. Consider `autocomplete="off"` on the driving field (autofill may not fire events).

### Static nested set

Fixed child count → plain `fields_for`, no JS.

### Dynamic nested rows

1. Server-render a `<template>` with one blank row and a placeholder index (`NEW_RECORD`).
2. Clone / `insertAdjacentHTML` after replacing the placeholder with a **unique numeric** index.
3. Container controller owns add/remove; use `closest('[data-…-row]')` for the row under the event.
4. Row-internal behaviour (e.g. friend vs guest) → **separate** controller identifier on the row.
5. Removal: unsaved → remove node; persisted → set destroy flag (or documented equivalent) and hide, so the instruction still submits.
6. Strong params must permit `:id` (and `:_destroy` when using nested attributes). Omitting `:id` on update duplicates children.

Index helper shape:

```javascript
#index = Date.now()

#nextIndex() {
  return this.#index++
}
```

**Index-less `foo[][key]` is unsafe** when rows have optional or disabled fields: Rack merges keys into the previous hash. Always use explicit numeric indices in the name attributes.

### Multiple instances on one page

Everything reachable from `this.element`; use `form.field_id` for per-instance ids; no document-global coupling.

### Turbo re-render survival

| Event | Controllers | Instance JS state |
|---|---|---|
| Drive visit / Frame / Stream replace | disconnect + connect | lost |
| Morph | often stays connected; `connect()` may skip | kept; attributes may be overwritten |

Design so both "connect re-runs" and "connect skipped" are correct. Protect in-progress input with dynamic `data-turbo-permanent` + unique `id` when morphing; reset permanent forms on `turbo:submit-end`. Clean transient UI on `turbo:before-cache` or mark `data-turbo-temporary`. Prefer not enabling global morphing casually.

### Server interaction choices

| Approach | When |
|---|---|
| Full POST/GET re-render | Default; validation; no-JS baseline |
| Turbo Frame / Stream HTML | Server knows facts; region must change |
| Embed in HTML (`values`, `<template>`, `data-*`) | Small, bounded, known at render time |
| JSON fetch | Client-owned widget with no server HTML equivalent — costly for 422 parity |

---

## Notes for AI coding agents

- **Declare shapes; don't sniff.** No `Array.isArray` / defensive `JSON.parse` stacks to "handle anything". Typed values + explicit params contracts.
- **Scope to the owning section.** Don't toggle every row via `querySelectorAll` on the form; use a row controller or `closest`.
- **Name the state owner in the plan** before coding (server / value / attribute / instance / URL) — exactly one place.
- **Assume replacement.** Answer Drive, back-cache, Stream replace, two instances, and double `connect()` before finishing.
- **Prefer the boring ladder rung.** "Dynamic form" does not mean fetch + client render.
- **Don't invent a JS framework** where the repo has none. Ship the minimum; raise tooling as an explicit decision.

Hard agent constraints also live in `.cursor/rules/hotwire-interactive-forms.mdc` (Apply Intelligently).

---

## Code-review checklist

**Params and server**

- [ ] Dynamic rows use unique, numeric indices; no index-less `[][key]` for optional/conditional rows
- [ ] Strong params match the submitted shape (`:id`, and `:_destroy` if nested attributes)
- [ ] Request spec posts the real payload (≥2 rows, inactive branch present)
- [ ] 422 re-render preserves rows and branch state
- [ ] No business rule enforced only in JavaScript

**HTML wiring**

- [ ] Every target/value/class declared `static` and present in markup (camelCase / kebab-case match)
- [ ] Values/classes on the same element as `data-controller`
- [ ] Row controller identifier ≠ container identifier
- [ ] No design-class / `nth-child` JS selectors
- [ ] Conditional groups `disabled` (prefer `<fieldset>`), not merely hidden; `required` matches visibility
- [ ] Radios/checkboxes: `<fieldset>` + `<legend>` first; `aria-controls` where relevant
- [ ] Cloned template has no duplicate bare `id`s (or ids come from `fields_for` + index)

**Controller**

- [ ] One responsibility; composed with siblings; named for behaviour
- [ ] No `document.querySelector` / `getElementById`; row via `closest` or per-row controller
- [ ] No duplicated state; no HTML-from-strings; no shape sniffing
- [ ] Optional targets use `has*Target`
- [ ] Derived UI in `valueChanged` / `targetConnected`, not a `connect()` target loop
- [ ] `disconnect()` releases what `connect()` acquired; prefer `data-action`
- [ ] `connect()` safe twice; `requestSubmit()` only

**Resilience**

- [ ] Correct after Frame/Stream replace and reconnect
- [ ] Correct with two instances on one page
- [ ] Transient UI cleaned on `turbo:before-cache` or `data-turbo-temporary`
- [ ] If morphing: protect focused input, reset on submit-end, veto attributes that must not morph

---

## Should NOT become Cursor rules

These need judgement; encoding them as hard rules trains agents to ignore the rule file.

1. Hard line-count caps on controllers
2. Frame vs Stream vs full render for a specific case (ladder is the rule; rung is judgement)
3. Nested attributes vs service / REST-per-child
4. Whether to enable Turbo morphing
5. Embed data vs fetch (payload size / staleness / privacy)
6. Outlets vs events for a specific pair
7. Whether this change needs Capybara / system tests
8. Whether to jsdom-unit-test a controller
9. Exposing a `connected` value for test sync
10. When to extract a plain module
11. Whether a controller is "reusable enough" before a second use
12. Accessibility beyond mechanical `fieldset` / `disabled` / `aria-controls`
13. Exact name of one controller (`player-fields` vs `participant-row`)

---

## Related

- Cursor rule (prohibitions): `.cursor/rules/hotwire-interactive-forms.mdc`
- Full evidence archive: research under the `rails-interactive-forms-guide` change (see pointer at top)
- Stack context: @context/foundation/tech-stack.md
