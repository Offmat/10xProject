---
date: 2026-07-25T16:30:00+02:00
researcher: Mateusz Leśniak
git_commit: c3fae220f1bf82c136990c3e8aff18ef31a69626
branch: main
repository: 10xProject (all-aBoard)
topic: "Engineering guide: interactive forms in Rails with Stimulus and Hotwire"
tags: [research, stimulus, hotwire, turbo, forms, nested-forms, frontend, testing, agent-rules]
status: complete
last_updated: 2026-07-25
last_updated_by: Mateusz Leśniak
---

# Research: Interactive forms in Rails with Stimulus and Hotwire

**Date**: 2026-07-25 16:30 (UTC+02:00)
**Researcher**: Mateusz Leśniak
**Git Commit**: c3fae220f1bf82c136990c3e8aff18ef31a69626
**Branch**: main
**Repository**: 10xProject (all-aBoard)

## Research Question

Produce a long-form engineering guide for building interactive forms in Rails with Stimulus (and Turbo where appropriate), grounded in official documentation, production 37signals codebases, and consistently-held community practice. Explain *why*, not just *what*, including trade-offs. Pay special attention to failure modes typical of AI coding agents (data-shape guessing, leaking state between repeated form sections, duplicated sources of truth, fragility under Turbo re-rendering). The guide is input for a later step that distills project-specific Cursor rules — it is not itself a rules file.

## Summary

**The single most important finding is a shape, not a rule: Stimulus is glue, and interactive forms are mostly a server-rendering problem wearing a JavaScript costume.** Every authoritative source converges on the same escalation ladder — plain HTML/CSS → a server round-trip (Turbo Frame or Stream) → a small Stimulus controller that toggles attributes → client-side templating (almost never). Both 37signals production apps I analysed sit near the bottom of that ladder: Fizzy has 69 Stimulus controllers with a **median of 31 lines** and *zero* uses of `fields_for` or `insertAdjacentHTML`; Campfire has 33 controllers, of which three account for 54% of all JavaScript, and the rest are tiny.

Ten principles carry most of the weight, each explained in the guide below:

1. **The DOM is the source of truth.** DHH, on the Turbo tracker: *"You should store state in the DOM to be able to deal with this gracefully."* Controllers are discardable; attributes survive.
2. **Escalate, don't start at the top.** Ask "does this need JavaScript at all?" before writing a controller, and "does the server know something the client doesn't?" before choosing a round-trip.
3. **One responsibility per controller, composed on one element.** `data-controller="form auto-submit nested-form"` is idiomatic; a 300-line `session-form` controller is not.
4. **Scope to the controller element, always.** `this.element`, targets, and `event.target.closest(...)` — never `document.querySelector` for anything a form owns. This is what keeps row three of a nested form from editing row one.
5. **A repeated section needs its own controller identity.** Stimulus scopes are *exclusive by identifier*: an outer `player-fields` controller cannot see targets inside a nested `player-fields` controller, and bubbling events from the inner one never reach the outer one's actions. Rows must use a *different* identifier from the container, or use `closest()` from the container.
6. **Never guess a data shape.** Values are typed and declared (`static values = { index: Number }`); `dataset` is always strings; `event.params` coerces; `JSON.parse` output is unknown until validated. Declare the interface, don't sniff it.
7. **Conditional fields need `disabled`, not just `hidden`.** A hidden-but-enabled input submits a stale value the server then has to reject. `<fieldset disabled>` removes the whole branch from submission *and* the tab order, and CSS can derive visibility from `:disabled`.
8. **Unique indices are a correctness requirement, not a formality.** Two dynamically added rows sharing an index means Rails silently keeps only the last one. `Date.now()` alone is not sufficient — two clicks (or a system test) inside one millisecond collide.
9. **Design for reconnection.** Turbo Drive body replacement, Frame navigation, Stream updates and morphing all re-run (or skip) `connect()` on DOM the controller did not create. `connect()` must be idempotent, cleanup must live in `disconnect()`, and in-progress input needs explicit protection (`data-turbo-permanent` applied *dynamically*, as Fizzy's `morph_guard` does).
10. **Test the wiring in a browser, unit-test only what you extracted.** Nobody credible unit-tests application Stimulus controllers in jsdom; the mistakes that actually happen are wiring mistakes (missing target, typo'd value, wrong event) that only a real browser catches.

The guide also records a **significant negative finding**: the widely circulated "37signals Stimulus conventions" do not exist as published rules. Fizzy's `AGENTS.md` contains no JavaScript guidance and its `STYLE.md` is Ruby-only. The conventions are real but are *code-as-documentation*; the popular gist claiming to be them is machine-generated and already stale (it says 52 controllers; `main` has 69). Cite the code, not the gist.

Finally, for **all-aBoard specifically**: the project has zero production Stimulus controllers today, six plain Turbo-Drive forms, no Turbo Frames or Streams, no morphing, and no browser tests. The upcoming S-03 session form (dynamic player rows, each row toggling friend/guest) is the first real interactive form, and it deliberately does *not* use `accepts_nested_attributes_for` — it posts a flat `players[]` array into `GameSessions::Create`. That choice removes some classic nested-form hazards and introduces one the literature doesn't cover: **Rack's `players[][key]` grouping is unsafe for rows with optional fields, so the form must use explicit indices.** Section 14 works the whole form through end to end.

## Evidence base

Three classes of source, weighted in that order.

**Official (normative).** Stimulus handbook and reference, Turbo source and tests, turbo-rails helpers. Cloned locally for line-accurate citation:

| Repo | Commit | Local path used during research |
|---|---|---|
| `hotwired/stimulus` | `6446f69` | `~/hotwire-research/stimulus` |
| `hotwired/turbo` | `f3faa2d` | `~/hotwire-research/turbo` |
| `hotwired/turbo-rails` | `37530c0` | `~/hotwire-research/turbo-rails` |
| `basecamp/fizzy` | `9ae6b3b` | `~/hotwire-research/fizzy` |
| `basecamp/once-campfire` | `69e8cd7` | `~/hotwire-research/once-campfire` |

Note that the Turbo *handbook* is not in the Turbo repo (it lives at turbo.hotwired.dev); mechanics cited from `src/` or from functional tests are marked as such, because implementation detail is a weaker promise than documentation.

**Production code (behavioural evidence).** Fizzy and Campfire, both 37signals, both Rails + Hotwire, analysed independently so that a pattern appearing in both counts as a convention rather than a quirk.

**Community (only where consistent).** thoughtbot (Sean Doyle is a Turbo committer, which makes those two articles the strongest non-official source in the whole survey), Boring Rails, Better Stimulus, Radan Skorić, David Colby, Rails Designer, Millarian, Stimulus Components, plus accessibility sources for the conditional-field question. Practices supported by three or more independent respected sources are stated flatly below; contested ones are marked **[contested]**; single-source opinions are marked **[single source]** and you should feel free to overrule them.

Two credibility warnings worth carrying forward. First, a cluster of consultancy/SEO blogs (ttb.software, useo.tech, oneuptime, reintech) restates correct advice in confident prose with unverifiable production anecdotes; where they are the *only* source for a claim, the claim is marked single-source. Second, several "Rails + Hotwire AGENTS.md" artifacts circulating publicly are themselves AI-generated summaries of codebases, so they corroborate nothing on their own.

## Detailed Findings

### 1. Division of responsibilities

The best way to prevent an over-engineered form is to be able to say, for any behaviour, whose job it is. The four-way split below is drawn from the Stimulus handbook's own framing plus Turbo's documented capabilities.

**The server owns truth, validation and rendering.** Every fact the user could reload the page and still expect to see is the server's: which games exist, who your accepted friends are, whether a score is valid, what the participants of a session are. The server also owns *what the form looks like in each state*, including the invalid state — a 422 that re-renders the form is a first-class part of the design, not an error path bolted on later.

**Rails owns naming, params and the HTML contract.** `form_with`, `fields_for`, `form.field_id`, `form.field_name` and strong params define the wire format. This matters more than it sounds: the majority of "interactive form" bugs are param-shape bugs (a duplicated index, a missing `:id`, a stale value from a hidden-but-enabled input), and every one of them is a Rails-side contract violation that happens to have been caused by JavaScript.

**Turbo owns navigation and partial replacement.** Full-page visits, Frames (a region navigates independently), Streams (the server names a target and an action), and morphing (in-place reconciliation). If a change requires the server's knowledge, it belongs to Turbo, not to Stimulus.

**Stimulus owns local, ephemeral behaviour on HTML it did not create.** Toggling an attribute, wiring a keyboard shortcut, submitting a form on change, cloning a `<template>`, calling `element.requestSubmit()`, instantiating a third-party widget and tearing it down again. The handbook is explicit that creating DOM is *"the minority use case. The focus is on manipulating, not creating elements"* (`stimulus/docs/handbook/00_the_origin_of_stimulus.md:54-58`), and that *"a Stimulus application's state lives as attributes in the DOM; controllers themselves are largely stateless"* (`05_managing_state.md:10`).

**When not to use Stimulus at all.** Four cases, in descending order of how often they're missed:

- *The browser already does it.* `<details>/<summary>` for disclosure, `<dialog>` for modals, the `popover` attribute for menus (light-dismiss and top-layer for free), `:checked ~ …` and `:has()` for CSS-only conditional reveals, `required`/`min`/`pattern` for first-pass validation. Fizzy is instructive here rather than dogmatic: it *ships* a `details_controller.js`, but the controller is 13 lines and does only the two things native `<details>` cannot — close programmatically and close on outside click. Use the native element; add a controller for the delta.
- *The server knows something the client doesn't.* Dependent dropdowns whose options come from the database, conditional sections whose availability depends on a policy, anything involving a lookup. Round-trip it.
- *You are about to write a template string.* If a controller builds HTML from data, you have chosen the wrong tool. The `<template>` element (server-rendered, cloned verbatim) is the sanctioned exception, and it is not templating — it is copying.
- *The state is genuinely large and client-owned* (a canvas, a spreadsheet, an offline editor). Then an island of something else is defensible. Note that Fizzy implements drag-and-drop Kanban in 150 lines of Stimulus, so this threshold is higher than people assume.

Inline `<script>` is worse than a small controller in all cases: it doesn't survive Turbo navigation predictably, it's invisible to grep, and it can't be tested. **[single source]** as an explicit claim, but it follows directly from Turbo's documented behaviour.

### 2. The escalation ladder

State the ladder once and refer back to it:

> **HTML → CSS → Turbo Frame → Turbo Stream → Stimulus (attribute toggling) → Stimulus (fetch + client render)**

Pick the leftmost option that solves the problem. The rationale is not purity, it's liability: every rung to the right adds a source of state that must be reconciled with the server's view of the world after the next Turbo update. Sean Doyle's version of the argument is the one to quote: *"Each line of application code is as much of a liability as it is an asset… Relying on browsers and Web protocols as much as possible frees up time and attention to spend on what's most important: the product."*

Two counter-pressures keep this honest. Rails Designer's objection is fair: *"there might be cases the round-trip to the server might be a bit much for simple, static HTML. After all, there's no extra data needed from the server to render the nested fields."* And a round-trip costs latency the user feels on every keystroke-adjacent interaction. So the practical test is the one already stated: **does the server know something the client doesn't?** If yes, round-trip. If no, a small client-side toggle is not just acceptable, it's better.

The failure this ladder prevents, concretely: a JSON-fetching, client-rendering "dynamic form" controller is 200 lines, duplicates the server's rendering logic, loses its state on the next Turbo update, has no server-side equivalent for the no-JS/validation-error path, and cannot be tested without a browser. The Frame version is a partial and three attributes.

### 3. State ownership

This is the most unanimous area in the entire survey, and also the one where AI-written controllers go wrong most often, so it's worth being mechanical about it.

**For every piece of state, name its owner before writing code.** Use this table as the decision procedure:

| State | Owner | Mechanism | Why |
|---|---|---|---|
| Domain data (participants, scores, games) | Server / DB | Rendered HTML, params | Survives everything; single source of truth |
| Whether a row is persisted | Server | Rendered attribute (`data-persisted`) or presence of an `id` field | Only the server knows |
| Which branch of a conditional section is active | Server on render, DOM after interaction | `checked` radio + `disabled` fieldset | Same attribute drives submission, visibility and re-render |
| Configuration for a controller (URL, limit, key) | Server | `static values` | Typed, defaulted, visible in HTML |
| Transient UI state (open/closed, active tab) | DOM | `static values` (+ `valueChanged`) or a class | Survives Drive cache restoration; readable in dev tools |
| Next index for a new row | DOM | derive from existing rows, or a monotonic counter on the controller | Must be unique; see §7 |
| Third-party widget instances, timers, observers | Controller instance | private fields (`#timer`), released in `disconnect()` | Not serialisable; must not leak |
| Shareable/bookmarkable UI state (filters) | URL | query params, server re-renders | Shareable, survives reload, morph-safe |

**Write to a value, react in `[name]ValueChanged`.** This is the mechanical expression of "DOM is truth" and it has a property people undersell: the flow is bidirectional. Anything that edits the attribute — another controller, a Turbo update, dev tools — flows back into your reaction. The reference confirms the callback fires *"after the controller is initialized and again any time its associated data attribute changes… includes changes as a result of assignment to the value's setter"* (`stimulus/docs/reference/values.md:105`), which is exactly why initialisation-on-page-load stops being a special case (see §6.9).

```javascript
// Canonical shape: no state on the instance, no duplicated truth.
export default class extends Controller {
  static values  = { open: Boolean }
  static targets = [ "panel" ]
  static classes = [ "hidden" ]

  toggle() { this.openValue = !this.openValue }

  openValueChanged() {
    this.panelTarget.classList.toggle(this.hiddenClass, !this.openValue)
  }
}
```

**Documented exceptions to "state in values":** non-serialisable objects (a date-picker instance), and anything sensitive you don't want in the HTML. Both stay in private instance fields, and both must be released in `disconnect()`.

**An honest caveat about `valueChanged`, because the production evidence is thin.** The docs and the community (Better Stimulus in particular) recommend it; 37signals barely uses it. Fizzy has **one** `*ValueChanged` callback in 69 controllers (`assignment_limit#countValueChanged`), and Campfire has **none** in 33. What both apps do instead is toggle attributes and classes directly in the action handler. So treat "react in `valueChanged`" as a well-founded recommendation for state that has more than one writer or must be re-derived after an external update — not as a pattern with heavy production precedent. For a one-writer toggle, doing the work in the action handler is what the reference apps actually do, and it's shorter.

**One real tension, worth knowing before you enable morphing: Turbo 8 morphing overwrites Stimulus value attributes with the server's version, and because the element is not replaced, `connect()` does not re-run to re-derive them.** This is reported and acknowledged upstream (`hotwired/turbo#1210`; Sean Doyle's own assessment there is that vetoing all server-sent values is *"safer than under-committing"*). The escape hatch is per-attribute:

```javascript
// Veto morphing of Stimulus value attributes, wholesale.
document.addEventListener("turbo:before-morph-attribute", (event) => {
  const { attributeName } = event.detail
  if (attributeName.startsWith("data-") && attributeName.endsWith("-value")) {
    event.preventDefault()
  }
})
```

**[contested]** — and the tension is real rather than resolvable: "put state in values" and "the server re-renders the truth" collide precisely when the server does *not* know the client state. Resolve it per value: configuration values should morph freely (that's the server correcting you); ephemeral client state either needs the veto above or shouldn't be a value at all — push it to the URL or to a user preference so the server *does* know it. Radan Skorić's framing is the right discipline: do that *"when it also has a UX benefit beyond fixing morphing"*, e.g. because it makes the state shareable.

**The common mistake:** two owners for one fact. A controller that keeps `this.open = true` *and* toggles a `hidden` class has two sources of truth that desynchronise on the first Turbo update. A form that keeps a row count in `this.rowCount` *and* in the DOM will disagree after a validation re-render. If you can't delete one of the two, you have a bug waiting.

### 4. Controller design

**Size: no published hard limit, but the observed norm at 37signals is small.** Measured from `fizzy@9ae6b3b`: 69 controllers, min 7 lines, **median 31**, mean 50, max 282 (`navigable_list_controller.js`, a keyboard-navigation engine). Fifteen controllers are ≤15 lines. Campfire is similar in shape but more skewed: 33 controllers, median ~33, and its three biggest (`composer` 194, `messages` 190, `notifications` 165) hold 54% of all controller code — those three are the genuinely hard parts of a chat client, and everything around them is tiny.

The useful reading of those numbers is not "keep controllers under 50 lines". It is: **the distribution should be lopsided.** Most behaviour in a well-factored Hotwire app is a handful of lines because the server did the work. If *every* controller in your app is 120 lines, the problem is architectural, not stylistic.

**Single responsibility, then composition.** The idiomatic move when a form needs four behaviours is four controllers on one element, not one controller with four concerns:

```erb
<%= form_with model: @game_session,
      data: { controller: "form nested-form",
              action: "turbo:submit-end->form#reset" } do |form| %>
```

Stimulus explicitly supports multiple identifiers per element (`stimulus/docs/reference/controllers.md:90-101`), and there is a documented ordering guarantee you can rely on: multiple controllers' callbacks fire in attribute order, and multiple actions for the same event fire left to right (`actions.md:259-281`). Sean Doyle's dynamic-forms implementation depends on exactly that to run `search-params#encode` before `element#click`.

Benefits: each piece is independently reusable and independently testable; the HTML documents the composition; deleting a behaviour is deleting an attribute. Drawback, and it's real: with four controllers on one element, the behaviour of the form is not readable from any single file. Mitigate by keeping the identifiers behavioural and boring — a reader who knows what `auto-submit` means doesn't need to open it.

**Name for behaviour, not for the page or the feature.** `nested-form`, `auto-submit`, `toggle-class`, `copy-to-clipboard`, `morph-guard`, `upload-preview` — all Fizzy names, all still meaningful in five years. `session-form`, `checkout`, `dashboard` are the anti-pattern: they attract unrelated code because their name gives no reason to say no, and they become `session-form-v2` within a year. Fizzy does use domain names (`boards_form`, `card_hotkeys`, `reaction_emoji`) where the behaviour genuinely *is* domain-specific — the rule is "name what it does", and sometimes what it does is domain-shaped.

**Build primitives, glue them per page.** Matt Swanson's formulation from 2020 still holds: *"you aren't making a `MessageList` component. You are making a generic async loading component that can render any provided URL."* Practically: parameterise via `static values` and `static classes` so the same controller serves three pages. Fizzy's `toggle_class` (31 lines) is used by filters, board menus and settings panels.

**Use the most specific lifecycle callback that exists.** The full documented set and its exact semantics (`stimulus/docs/reference/lifecycle_callbacks.md:26-90`):

| Callback | Fires | Use it for |
|---|---|---|
| `initialize()` | once per instance, ever | binding debounced methods, creating formatters |
| `[name]TargetConnected(el)` | every time a matching target appears — **before** `connect()` on first pass | per-element setup for elements that may arrive later |
| `connect()` | every time the controller element connects; **may fire many times on the same instance** | wiring that isn't expressible in HTML |
| `[name]ValueChanged` | at initialisation *and* on every attribute change | rendering derived from state |
| `[name]TargetDisconnected(el)` | when a target leaves — **after** `disconnect()` on teardown | per-element cleanup |
| `disconnect()` | every time the element disconnects | releasing everything `connect()` acquired |

Three consequences that matter for forms. (a) **Instances are reused across reconnection** — the docs say Stimulus *"reuses the previous controller instance"* and calls `connect()` again, so anything you accumulate in `connect()` accumulates. (b) **`connect()` must be idempotent**; the Turbo handbook devotes a section to making transformations idempotent, typically by marking processed elements with an attribute. (c) **Target callbacks are how you stay correct under Turbo** — a row appended by a Stream, a field arriving in a lazy Frame, a `<template>` clone inserted by a sibling controller all fire `[name]TargetConnected` without any `connect()` involvement. Preferring target callbacks over "loop over targets in `connect()`" is the single highest-leverage lifecycle habit for dynamic forms.

**Prefer `data-action` in HTML over `addEventListener` in `connect()`.** Stimulus does the add/remove bookkeeping (so you cannot leak a listener), and the wiring is greppable from the markup. Both 37signals apps take this to an extreme: Campfire has exactly one `addEventListener` in a controller and *zero* `removeEventListener`, because everything — including Turbo lifecycle events — is declared in HTML, and complex action strings are assembled in Ruby helpers (`once-campfire/app/helpers/messages_helper.rb:70-84`). That helper trick is worth stealing: it keeps a 200-character action string out of the ERB while keeping it server-side and testable.

Legitimate reasons to attach manually: the event doesn't dispatch inside your subtree, or the controller must work merely by being attached (Fizzy's `auto_submit` listens for `turbo:submit-end` with `{ once: true }` in `connect()` for exactly this reason). Pair every one with a `disconnect()`.

**Extract non-DOM logic to a plain module.** Campfire is the model: `models/message_paginator.js`, `models/file_uploader.js`, `models/scroll_manager.js`, `lib/autocomplete/*` — the controllers are glue over plain classes. Benefit: the algorithm is unit-testable without a DOM, and the controller stays readable. Drawback: indirection, and for a 20-line behaviour it's overhead. Threshold: extract when the logic has its own vocabulary and no DOM dependency.

### 5. HTML architecture

The attributes are the API. Getting them wrong is the most common source of "the controller doesn't fire" and the most common source of cross-row leakage.

**`data-controller`** puts one or more identifiers on an element; the element plus its descendants is the scope. Two rules with sharp edges:

- **Scopes are exclusive per identifier.** *"When nested, each controller is only aware of its own scope excluding the scope of any controllers nested within"* (`controllers.md:73-88`). An outer `list` controller cannot see `data-list-target="item"` inside an inner `data-controller="list"`.
- **The consequence people discover the hard way**: a *bubbling event dispatched from a nested same-identifier controller never reaches the outer one's action.* The mechanism is `Scope#containsElement`, which asserts `element.closest(this.controllerSelector) === this.element`; for a nested identical controller, `closest()` stops at the child. Sam Stephenson's own conclusion on the issue thread: *"I suspect the best solution is to use two separate controllers."* Do that; don't use the `target: this.element.parentElement` trick that circulates as a workaround.

**`data-action`** is `event->identifier#method`, with defaults worth memorising because they remove noise: `form` → submit, `input`/`textarea` → input, `select` → change, `button`/`a` → click, `details` → toggle (`actions.md:55-66`). Modifiers: `@window`, `@document` for global listening; `:prevent`, `:stop`, `:once`, `:passive`, `:self` as options; `.enter`, `.esc`, `.ctrl+enter` keyboard filters. Multiple actions per element are space-separated and ordered.

`data-*-param` attributes are the underused feature: they arrive as `event.params` **with type coercion**, which lets a button carry structured data without you parsing `dataset` by hand. Note the scoping rule — a shared button only delivers params to actions of the *same* controller (`actions.md:331-344`).

**Targets** are `data-<identifier>-target="name"`, exposed as `this.nameTarget` (first match, **throws if absent**), `this.nameTargets` (all, document order), `this.hasNameTarget` (boolean). Use `hasNameTarget` whenever the element is genuinely optional — Fizzy's shared `form_controller` does `const input = this.hasInputTarget ? this.inputTarget : null`, which is why the same controller serves forms with and without an input. One target element can serve several controllers simultaneously; Campfire puts four target attributes plus an outlet on one message div.

**Values** are `data-<identifier>-<name>-value`, declared with types, and this is the mechanism that eliminates data-shape guessing:

```javascript
static values = {
  url:      String,
  index:    { type: Number, default: 0 },
  filters:  Array,          // JSON-encoded in the attribute
  settings: Object          // JSON-encoded in the attribute
}
```

Defaults when the attribute is absent are `""`, `0`, `false`, `[]`, `{}` by type, so a value is never `undefined` — which means a controller reading `this.filtersValue.forEach(...)` cannot crash on missing markup, and does not need a defensive `Array.isArray` check. Setting a value writes the attribute; setting `undefined` removes it.

**Classes** are `data-<identifier>-<logical>-class`, read as `this.logicalClass`. The point is that CSS names stay in HTML where a designer expects them. With Tailwind/daisyUI this is more than tidiness: a hardcoded `"opacity-60"` in JavaScript is invisible to Tailwind's content scanner in some configurations and invisible to whoever restyles the component.

**Outlets** are `data-<identifier>-<other>-outlet="<selector>"`, giving direct access to another controller's instance. Three properties of outlets to internalise: the outlet name **must** equal the target controller's identifier; the matched element **must** carry `data-controller` with that identifier or Stimulus throws; and **the selector is global** — it is not scoped to your element, so a selector that looks row-local will happily match a row elsewhere on the page. That last one makes outlets a poor fit for repeated form sections.

Usage in production is telling: Fizzy uses outlets in **3 of 69** controllers, Campfire in **2 of 33**. Both apps coordinate overwhelmingly through events and shared DOM.

**Common HTML-architecture mistakes**, in the order I'd look for them in review:

| Mistake | Symptom | Fix |
|---|---|---|
| Value attribute on the wrong element | value is silently the default | values and classes must be on the *same element* as `data-controller` |
| Target used but never declared in `static targets` | `undefined is not a function` | declare it; the attribute alone does nothing |
| Kebab/camel mismatch (`data-nested-form-target` vs `nestedForm`) | target/value never resolves | identifier kebab-cases; the target *name* is camelCase in both places |
| Same identifier nested inside itself | outer controller mysteriously ignores inner rows | give the row a different identifier |
| `document.querySelector` in a controller | works with one instance, breaks with two | target, or `this.element.querySelector`, or `closest()` |
| Selector-based outlet using a design class | breaks on restyle; matches unintended elements | match `[data-controller~="thing"]`, and prefer events |
| Fragile selectors (`.btn.btn-primary`, `div > div > input`) | breaks on markup or theme change | target attributes are the stable contract |
| Behaviour attached to an element Turbo replaces, state kept in JS | works until the first Stream update | move state to attributes |

### 6. Interactive form patterns

A catalogue. Each entry: the mechanism, why it's shaped that way, and the mistake to look for.

#### 6.1 Radio buttons that control other fields

Server renders the current branch; the radio's `change` action flips a `disabled` fieldset; CSS derives visibility from `:disabled`.

```erb
<%= form.radio_button :access, "public",
      data: { action: "player-fields#toggle" }, "aria-controls": "public_fields" %>

<%= field_set_tag nil, id: "public_fields", disabled: !@doc.public?,
      class: "disabled:hidden", data: { player_fields_target: "branch" } do %>
  <%= form.text_field :passcode %>
<% end %>
```

Why `disabled` and not `hidden`: a hidden-but-enabled input still submits, so the server receives a stale value from the branch the user abandoned and either persists it or rejects the form for a field the user can't see. `disabled` removes the control from submission *and* from the tab order, so keyboard users don't land in invisible fields. And because the *server* renders the same `disabled` attribute from model state, the validation-error re-render is automatically correct with no extra code — one attribute is doing four jobs. This is Sean Doyle's pattern; the accessibility literature (GOV.UK, TetraLogical) independently agrees on `disabled` semantics and on `<fieldset>`/`<legend>` for the radio group itself.

Accessibility specifics that are cheap to get right and expensive to retrofit: group the radios in `<fieldset>` with `<legend>` as the *first child* (otherwise the grouping isn't exposed at all), point the trigger at the section with `aria-controls`, and keep `required` in sync with visibility — a hidden `required` field blocks submission with an error nobody can see.

Mistake to look for: `element.hidden = true` alone; and `style.display = "none"` (fights inline-style specificity, and can't be overridden by CSS).

#### 6.2 Checkboxes

Same shape. Two extras. First, a "check all" needs to be scoped: `this.element.querySelectorAll('input[type=checkbox]')`, never `document`. Fizzy's `filter_form_controller` (11 lines) is the reference — it scopes by `name` *within* `this.element`. Second, remember Rails renders a hidden `0` field before each checkbox; JavaScript that disables or removes "the input" must account for the pair, or you'll submit neither value.

#### 6.3 Dependent dropdowns

The server owns the options, so this is a round-trip. Wrap the dependent field in a Frame and drive it from the parent field's change:

```erb
<%= form.select :country, countries, {}, autocomplete: "off",
      data: { action: "change->element#click" } %>

<turbo-frame id="<%= form.field_id(:state, :frame) %>" class="contents">
  <%= form.select :state, @states.presence || [] %>
</turbo-frame>

<button formmethod="get" formaction="<%= new_address_path %>" hidden
        data-element-target="click"
        data-turbo-frame="<%= form.field_id(:state, :frame) %>"></button>
```

Two details that are easy to miss and expensive to debug. **`formmethod="get"` + `formaction`** means the browser re-encodes the *current form values* as query params, so `#new` can read `params.fetch(:address, {}).permit(...)` and re-render — which also means the whole feature works with JavaScript disabled if you leave the button visible (wrap it in `<noscript>`). And **`autocomplete="off"` on the driving field** is load-bearing: browser autofill restores values *without dispatching events*, so on back-navigation the dependent field silently desynchronises. **[single source]** for the autocomplete point, but nothing contradicts it and the failure is real.

Why a Frame rather than a full-page render: focus and scroll outside the frame are preserved, so the select the user is operating keeps focus. Drawback: content *outside* the frame goes stale, and if the dependent change should also update a summary elsewhere you need a second mechanism (Doyle's trick is to include an inert `<turbo-stream>` element inside the frame response, which Turbo executes on connect).

Anti-pattern for this case: embedding every country's states in the page. Doyle counted 3,391 elements per render for country→state. Also an anti-pattern: fetching JSON and building `<option>` elements in JavaScript — you've now got server option rendering in two places.

#### 6.4 Conditional sections

As §6.1, plus: derive the initial state from the server, never from "whatever the first radio happens to be". The invariant to hold is *the form after a validation error must look exactly like the form the user submitted*, and the only way to get that free is to have the server render the branch state from the model.

#### 6.5 Nested fields (static set)

If the number of children is fixed and known (e.g. exactly two scores), plain `fields_for` with no JavaScript is the whole answer. Reach for §6.6 only when the count is user-controlled.

#### 6.6 Dynamically added nested forms

See §7 for the full treatment. Shape: a server-rendered `<template>` containing one blank row with a placeholder index, cloned on click, placeholder replaced with a unique index, appended to a container target.

#### 6.7 Removing nested forms

Branch on persistence. Unsaved row: remove the node. Persisted row: set the `_destroy` hidden field to `"1"` and hide the row with the `hidden` attribute (do not remove it — a removed node submits nothing, so the server never learns to destroy the record). With a service-layer API instead of nested attributes (all-aBoard's case), the equivalent is: unsaved rows vanish, persisted rows keep submitting their `id` with a `_destroy`-equivalent flag, or the service treats "absent from the submitted list" as removal — that must be an explicit, documented decision, because the two conventions are indistinguishable from the HTML.

#### 6.8 Multiple instances of the same form on one page

Everything a controller touches must be reachable from `this.element`. That means: no `document.getElementById`, no `id`-based coupling that isn't generated per instance (`form.field_id` exists for this), no global event names that don't carry an identity in `detail`. If you can't render the form twice on one page without the two interfering, the controller is coupled to the document rather than to its element — and that same coupling is what breaks it later inside a Turbo Frame or a stream-appended list.

#### 6.9 Preserving state and initialising on page load

The instinct is a `connect()` that reads the DOM and applies initial state. Prefer instead: **the server renders the correct initial state**, and the controller only reacts to change. If you must derive something on load, do it in `[name]ValueChanged` (fires at initialisation, so load and update share one code path) or in `[name]TargetConnected` (fires for elements that arrive later too). Both are strictly better than `connect()` because they also handle the Turbo cases for free.

For text the user has typed and you must not lose across a *cached* back-navigation, Fizzy's answer is `local_save_controller.js` (localStorage keyed from ERB) rather than trying to make Turbo preserve it.

#### 6.10 Turbo re-rendering

The four ways your form's DOM can change under you, and what survives:

| Event | Controllers | JS instance state | Input values |
|---|---|---|---|
| Drive visit (new `<body>`) | disconnect + connect | lost | lost (unless `data-turbo-permanent` + `id`) |
| Drive cache restore (back) | connect on restored HTML | lost | as cached — which may be stale |
| Frame navigation | disconnect + connect inside frame | lost | lost inside the frame |
| Stream `replace`/`update` | disconnect + connect on replaced subtree | lost | lost in the replaced region |
| Morph | often **stays connected**; `connect()` may be **skipped** | kept (but attributes overwritten) | preserved for focused inputs per Turbo's tests, not guaranteed generally |

The design consequence: a controller must be correct both when `connect()` re-runs *and* when it doesn't. That is the strongest available argument for keeping derived rendering in `valueChanged` rather than `connect()`. §10 covers the mitigations.

### 7. Dynamic nested forms, in depth

This is where interactive Rails forms actually go wrong, so it gets the longest treatment. I compared six independent published implementations (Stimulus Components' `rails-nested-form`, Millarian's Rails 8 write-up, Rails Designer, Drifting Ruby, a Medium write-up, and `stimulus-library`'s `NestedFormController`). They agree on the architecture and differ only in cosmetics.

#### 7.1 The canonical pattern

```erb
<%= form_with model: @project, data: { controller: "nested-form" } do |form| %>
  <div data-nested-form-target="list">
    <%= form.fields_for :tasks do |task| %>
      <%= render "task_fields", form: task, persisted: task.object.persisted? %>
    <% end %>
  </div>

  <template data-nested-form-target="template">
    <%= form.fields_for :tasks, Task.new, child_index: "NEW_RECORD" do |task| %>
      <%= render "task_fields", form: task, persisted: false %>
    <% end %>
  </template>

  <button type="button" data-action="nested-form#add">Add task</button>
<% end %>
```

```javascript
export default class extends Controller {
  static targets = [ "list", "template" ]

  // Monotonic and numeric: unique across clicks, and still a valid Rails index.
  #index = Date.now()

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", this.#nextIndex())
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove({ target }) {
    const row = target.closest("[data-nested-form-row]")
    if (!row) return

    if (row.dataset.persisted === "true") {
      row.querySelector("input[name*='_destroy']").value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }

  #nextIndex() {
    return this.#index++
  }
}
```

**Why a `<template>` and not a JavaScript string.** The row's markup is rendered by Rails, so field names, ids, labels, i18n, daisyUI classes and nested partials all come from one place. `<template>` content is inert — not submitted, not validated, images not loaded — so it costs nothing until cloned. Building the row in JavaScript duplicates the server's rendering and guarantees drift.

**Why `Task.new` is passed explicitly to the template's `fields_for`.** Without it, `fields_for` iterates whatever the controller already built, so if `new` does `2.times { @project.tasks.build }` your template contains two rows and one click adds two.

**Why the index must be unique — this is a correctness bug, not a nicety.** Rails maps `tasks_attributes[<index>]` to child records; two new rows sharing an index means Rails sees one child and **silently saves only the last**. Every source uses a timestamp (`Date.now()`, `new Date().getTime()`, `Time.current.to_i`) and **none of them addresses collisions**. Two clicks within the same millisecond — trivially reachable from a fast double-click, an "add 3 rows" convenience button, or a Capybara test — produce the silent-drop bug. Hence the monotonic counter seeded from `Date.now()` above.

**And the index must be numeric.** This is easy to miss because timestamps are numeric by accident. `ActionController::Parameters` decides whether a nested hash is "fields_for-style nested params" by checking that *every* key matches `/\A-?\d+\z/`; only then does it apply your filter to each child hash. So an index like `1753452000000_0` — or a UUID — makes `permit(players: [ :type, :score ])` stop behaving as intended, silently. Keep indices numeric strings; `crypto.randomUUID()` is tempting and wrong here.

**Why removal branches on persistence.** A removed DOM node submits nothing, so for a saved child the server never learns to destroy it. Setting `_destroy = "1"` and hiding the row keeps the instruction in the payload. For unsaved rows, actual removal is right — an unsaved row with `_destroy` set is at best noise and, without `reject_if: :all_blank`, can persist an empty child.

**Server side.** `accepts_nested_attributes_for :tasks, allow_destroy: true, reject_if: :all_blank`, and permit both `:id` and `:_destroy`:

```ruby
params.expect(project: [ :name, tasks_attributes: [ [ :id, :title, :done, :_destroy ] ] ])
```

`allow_destroy` is what makes `_destroy` mean anything; `reject_if: :all_blank` drops rows the user added but never filled in; **omitting `:id` makes Rails treat every submitted row as new on update, so edits become duplicates.** Note the doubled brackets in the Rails 8 `params.expect` form for an array of hashes — a single-bracket version silently permits nothing useful.

#### 7.2 Scoping to one row: the part agents get wrong

**Use `event.target.closest(...)` (or a per-row controller), never a global selector, and never index arithmetic over `this.rowTargets`.** All six implementations put *one* controller on the form and use `closest()` for per-row scoping; that is the community's converged answer, not a controller per row.

The failure mode this prevents is specific: a `remove()` that does `this.rowTargets[this.rowTargets.length - 1].remove()`, or `document.querySelector(".player-row")`, removes the wrong row as soon as there are two — and it looks correct in a one-row manual test. Similarly, a `toggle()` that does `this.element.querySelectorAll(".friend-select").forEach(...)` toggles *every* row's select, because `this.element` is the whole form.

Three legitimate scoping tools, in order of preference:

1. **A target on the row plus `closest()` from the event target** — for actions triggered inside a row and handled by the container controller. Mark the row with an attribute you own (`data-nested-form-row`), not a design class.
2. **A separate controller per row** — for behaviour that is entirely internal to a row (the friend/guest toggle). Then `this.element` *is* the row, and every target lookup is automatically row-local. This is the strongest guarantee available, and it composes: the container controller handles add/remove, the row controller handles the row's internals, and neither knows about the other.
3. **`event.params`** — when a button needs to identify a row by id rather than by DOM position.

**The trap when combining 1 and 2**: the row controller must have a *different identifier* from the container. If both are `nested-form`, the container silently loses visibility of the rows' targets and bubbling events from rows never reach the container's actions (see §5). Naming them `nested-form` and `player-fields` costs nothing and removes the whole class of bug.

#### 7.3 Avoiding state leakage between repeated sections

Concrete checklist for a repeated section:

- Does the controller ever touch `document`? If yes, it can leak.
- Does it hold anything derived from *the current row* in an instance field? Two rows share nothing, but two *instances* of the same row controller each have their own instance fields — that's fine. What's not fine is the *container* holding "the currently active row" in an instance field, because that's a second source of truth for something the DOM already knows.
- Are ids unique? Cloning a `<template>` copies `id` and `for` attributes verbatim. If the row's markup contains ids, they are duplicated the moment you add a row, which breaks label/input association and any `getElementById`. Fizzy's `multi_selection_combobox` explicitly does `field.removeAttribute("id")` after cloning for exactly this reason. Using `child_index` in `fields_for` makes Rails generate unique ids for you — which is another reason to render the row through `fields_for` rather than by hand.
- Is any event dispatched by a row identified? An unqualified `this.dispatch("changed")` bubbling to a container listener tells the container *something* changed but not *what*; put the row element or its index in `detail`.

#### 7.4 The alternative worth knowing: skip nested attributes entirely

Three respected write-ups argue that if the parent already exists, each child should be its own REST resource whose `create`/`update`/`destroy` render Turbo Streams — no `fields_for`, no `child_index`, no `_destroy`, and none of §7.1's bugs. Millarian's trade-off summary is blunt: *"The only thing you give up is the ability to create parent and children in a single transaction."* **[contested]** — the same author publishes both approaches, which is the honest position.

When it fits: an existing parent, children that are independently meaningful, and an appetite for one endpoint per child type. When it doesn't: creating parent and children together in one submit (all-aBoard's session form — you cannot POST a participant before the session exists), or when the whole thing must succeed or fail atomically.

`cocoon` is unmaintained and its Webpacker era is over; the replacement is the ~20 lines above, optionally via `@stimulus-components/rails-nested-form` if you'd rather depend than paste. **[contested]** on package-vs-paste; for one form, paste.

### 8. Communication between controllers

Four mechanisms. The community publishes two conflicting *orderings* of them, but agrees completely on the *decision rule*, so use the rule.

**Prefer, in this order:**

1. **Shared DOM / attributes.** Controller A writes an attribute; controller B reacts via `valueChanged` or `targetConnected`. Zero coupling, no event names to invent, and the interaction is visible as an HTML diff. This is the least-discussed and often the cleanest option, and it falls out automatically if both controllers follow §3.
2. **Custom events via `this.dispatch()`.** Use when the emitter should not care whether anyone is listening, or when the audience is unknown/many. The event name is `identifier:name` by default; `{ prefix: false }` and `{ target: document }` let you opt out (Fizzy's 9-line `dispatch_event_controller` exists purely to fire a named event at the document from markup). Defaults are `bubbles: true, cancelable: true, detail: {}, target: this.element`. Wire the listener declaratively: `data-action="filter:changed->nav#reset"`.
3. **Outlets.** Use when there is a genuine one-to-one or parent→known-children relationship and you want to *call a method*. Benefit: precise addressing and a debuggable call stack. Costs: the selector is global (a row-local-looking selector can match other rows), the target element must carry `data-controller`, the markup gets bulky, and an empty match is silently valid — so a renamed class breaks the wiring with no error.
4. **`application.getControllerForElementAndIdentifier`.** The docs say to use it only when a problem *"cannot be solved through… events"*. No respected source recommends it; outlets exist because this used to be the workaround.

**Rules of thumb, stated as questions:**

- Should the emitter care if nobody listens? No → event. Yes → outlet.
- Is the audience known and singular? Yes → outlet. No → event.
- Is the thing being communicated a *state change* rather than an *occurrence*? → shared DOM/value.
- Is the receiver in a different subtree with no common ancestor? → event on `@window`/`@document`, or an outlet.

**When not to use each.** Don't use events as a substitute for structure — twenty controllers listening for `document`-level app events is unsearchable. Don't use outlets across repeated sections. Don't use *values* as a message channel (a value that means "please do X now" instead of "the state is X" is an event wearing the wrong clothes). And never reach into another controller's DOM: *if controller A queries elements owned by controller B, you have one controller in two files.*

**Production evidence for the ordering:** Fizzy dispatches events from 6 controllers with ~60 declarative listeners in ERB, versus 3 outlet users; Campfire has 8 dispatchers and 2 outlet chains. Both use outlets for exactly the case the rule predicts — a composer calling a method on the message list.

**Parent/child specifically.** Prefer the parent driving children through the DOM (write an attribute on each child; children react) and children informing the parent through bubbling events. This keeps both reusable and avoids the same-identifier bubbling trap. Ben Nadel's framing is apt: *"neither controller knows about the other, all linkage is powered by the actual DOM tree."*

### 9. Server interaction: four options and when each is right

| Approach | Use when | Benefits | Drawbacks |
|---|---|---|---|
| **Full server render** (normal form POST / GET) | default; anything with validation; the no-JS baseline | one rendering path, works everywhere, no client state | full-page flash, loses focus/scroll, feels heavy for micro-interactions |
| **Fetch partial HTML** (Turbo Frame or Stream) | the server knows something the client doesn't; a region must change | server keeps owning rendering; focus/scroll outside the region survive; no client templating | latency per interaction; frame boundaries constrain layout; content outside the region can go stale |
| **Fetch JSON** | populating a *client-owned* widget (autocomplete list, chart) whose rendering has no server equivalent | small payloads; cache-friendly | you now own rendering in two languages; every render path must be re-implemented for the validation-error case |
| **Embed data in HTML** (`static values`, `<template>`, `data-*`) | the dataset is small, bounded and known at render time | zero latency, no extra endpoint, no client fetch state | payload grows with the data; the data is a snapshot that goes stale; leaks anything you wouldn't show the user |

The line between the last two is quantitative and worth stating in review terms: embedding is fine for tens of items, wrong for thousands (country→state as one blob = 3,391 elements per render). Embedding *behaviour configuration* (a URL, a limit, a key) is always fine — that's what values are for.

For all-aBoard's scale — a ~20-game catalogue and a handful of friends — **embedding is the right answer for the friend list and game list**, and no fetch of any kind is needed for the session form. That is worth saying out loud, because "dependent dropdown" pattern-matching would otherwise pull in a Frame round-trip the data volume doesn't justify.

One asymmetry that catches people: **a JSON round-trip is the only option with no server-rendered fallback.** If the same UI must also work in the 422-re-render path, HTML-returning options give it to you for free and JSON does not.

Also: choose the response format deliberately when a background save could clobber the user's typing. Fizzy's autosave posts and asks for **JSON** specifically so the server's Turbo Stream response — whose first action morphs the container that *is* the form being typed in — never runs. The comment in `fizzy/app/javascript/helpers/form_helpers.js:3-9` is the clearest statement of that hazard I found anywhere, including the docs.

### 10. Resilience: surviving Turbo

An interactive form must be correct after: a Drive visit, a cached back-navigation, a Frame replacement, a Stream update, a morph, a reconnect, and being present more than once. Here is what each requires.

**Turbo Drive caching (back button).** Turbo snapshots the page *before* leaving and may render that snapshot as a preview on return. Anything transient must be cleaned up at `turbo:before-cache`, or the user sees stale UI on the way back. Mechanisms: `data-turbo-temporary` (element is removed before caching — right for flash messages), a `turbo:before-cache` action that closes dialogs and resets widgets (Fizzy does this in ~15 places: `turbo:before-cache@document->dialog#close`), and `<meta name="turbo-cache-control" content="no-preview">` as a last resort. A specific form hazard reported repeatedly: a **422 validation-error render gets cached**, so the back button shows errors on data the user has already fixed.

**Frames.** Replacing a frame disconnects and reconnects everything inside it. Therefore: don't keep form state outside the frame that depends on markup inside it; expect `connect()` to run again; and remember `turbo:frame-missing` exists and throws by default if the response has no matching frame — a mis-scoped redirect from a form inside a frame is the usual cause.

**Streams.** `append`/`prepend`/`before`/`after` deduplicate by child `id`, and `target` is resolved with `getElementById`. So stream-driven form rows need stable, unique ids — which is another argument for `fields_for` + `child_index` generating them. Campfire has a subtle trick worth knowing when a stream can race a form submission: `turbo_streaming#unsubscribe` **removes the container's `id` on `turbo:submit-start`**, so in-flight broadcasts can't target it while the full response is on its way (`once-campfire/app/javascript/controllers/turbo_streaming_controller.js:3-10`).

**Morphing.** The important upstream fact: **Turbo deliberately does not protect the focused input's value during a morph.** `ignoreActiveValue: true` was added and then reverted in `hotwired/turbo#1195` because it made it impossible to clear a form after submission; the PR states the intended replacement is for applications to *"set `[data-turbo-permanent]` when form control receives focus… then remove it… when the form control loses focus."* David Colby's description of the failure is the one to remember: *"the server does not know that the user is currently halfway through writing a novel in a form input."*

The full mitigation kit, in the order you should reach for it:

1. **`data-turbo-permanent` + a unique `id`** on the element that must not be touched. Both attributes are required (Turbo's selector is `#${id}[data-turbo-permanent]`). Note this also works for non-morph replacement: Turbo swaps the live nodes in, so *the same JavaScript objects and listeners survive*.
2. **Apply it dynamically, not in server markup.** If the attribute is always present, the element can never be updated by anyone. Fizzy's `morph_guard_controller.js` is the production answer and is worth quoting in full because it is 16 lines and solves a whole category:

```javascript
// fizzy@9ae6b3b app/javascript/controllers/morph_guard_controller.js
export default class extends Controller {
  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.frame?.setAttribute("data-turbo-permanent", "")
  }

  disconnect() {
    this.frame?.removeAttribute("data-turbo-permanent")
  }
}
```

Attach it to the *edit form*; while an edit is in progress the enclosing frame is permanent, and the moment the form goes away the frame is morphable again. Display mode stays fresh, in-progress edits are safe, and no server markup mentions permanence.

3. **Pair permanence with an explicit reset.** `data-turbo-permanent` alone means the form never clears for the user who submitted it. The three-line fix everyone converges on:

```erb
<%= form_with model: @comment,
      data: { controller: "form", action: "turbo:submit-end->form#reset" } do |form| %>
```

4. **Veto a single attribute** when the element *should* update but one piece of UI state must not be overwritten: `turbo:before-morph-attribute` + `event.preventDefault()`. Typical cases are `open` on `<details>`/`<dialog>` and `data-*-value` attributes (§3).
5. **Push the state to the server or URL** so the morph converges on the right thing instead of fighting it. This is the only option that eliminates the problem rather than suppressing it.

Two respected sources advise **not** enabling page-refresh morphing globally yet (thoughtbot, Dec 2024: *"morphs are sharp knives"*), while Radan Skorić advocates incremental adoption via scoped `replace`/`update` with `method="morph"`. **[contested]**. For all-aBoard the decision is easy and should be made explicitly: morphing is not enabled, nothing needs it, and enabling it later is a change with its own review — not a side effect of a form ticket.

**Reconnect and multiple instances.** Everything above assumes the controller is written so that: `connect()` is idempotent (guard with an attribute if the operation isn't naturally repeatable), `disconnect()` releases everything `connect()` acquired, and no behaviour depends on being the only instance. There is no such thing as a permanent Stimulus controller — DHH closed that request with *"You should store state in the DOM to be able to deal with this gracefully."*

**Dynamically inserted DOM.** Prefer `[name]TargetConnected` over loops in `connect()`; then rows appended by your own controller, by a Turbo Stream, or by a lazy frame are all handled by one code path. Be aware of one documented subtlety: while a target callback is running, adding or removing a same-named target does **not** re-invoke the callback (`stimulus/docs/reference/targets.md:117-120`) — so a `rowTargetConnected` that appends another row won't recurse, which is usually a relief and occasionally a surprise.

### 11. Testing

**The consensus, stated plainly: test the behaviour in a real browser; unit-test only logic you deliberately extracted from the controller.** The Stimulus core team's own answer (issue #34) is *"we write high level feature tests using [Rails] system testing."* Both 37signals apps do exactly this and have **zero** JavaScript unit tests — Fizzy: 4 system tests (Minitest + Capybara + Selenium) plus controller tests; Campfire: 3 system tests plus turbo-stream broadcast assertions.

**Why not jsdom unit tests for application controllers.** Dimiter Petrov's argument is the sharpest published version and matches my reading of both codebases: *"In applications, the mistakes I commonly make with Stimulus controllers are all in the integration with the page. Maybe I forgot to set a target, or I have a typo in a value, or it's not listening to the right event… I could get it right in the test code, but wrong in the production."* A jsdom test builds its own fixture HTML, so it validates the controller against markup that isn't the markup you ship — it cannot catch the class of bug that actually occurs. **[contested]** in that some sources do recommend Vitest/Jest controller tests for complex controllers; the reconciliation everyone would accept is: extract the algorithm to a plain module, unit-test that fast, and system-test the wiring.

**The cheap layer nobody should skip: assert the wiring server-side.** Fizzy does `assert_select "form[data-controller='auto-submit']"` in a controller test (`fizzy/test/controllers/searches_controller_test.rb:41`). In RSpec request specs, the equivalent is asserting that the rendered form carries the expected `data-controller`, targets and template. This costs milliseconds, needs no browser, and catches the most common regression (someone edits the ERB and drops an attribute).

So the pragmatic triad, in cost order:

1. **Request spec** — the form renders with the right `data-*` wiring; the endpoint accepts the exact params the form produces (this is the highest-value test for a dynamic form, see below); validation failure re-renders with status 422 and preserves the submitted rows.
2. **Service/model spec** — business rules on the params shape.
3. **One JS-enabled system spec** — the happy path through the interactive parts.

**The highest-value test for a dynamic nested form is a request spec that posts the exact payload the DOM would produce**, including two dynamically-added rows with distinct indices and one row where a branch was disabled. It catches index collisions, param-shape errors and missing permits without a browser, and it's the one test that would have caught every param bug in the six implementations I compared.

**Edge cases to cover.** The literature does not enumerate these — I derived them from documented failures, so treat the list as this guide's contribution rather than as received wisdom:

- Add two rows, then submit → both persist (catches duplicate indices).
- Add a row, submit invalid, re-render, submit valid → added rows survive the 422 (catches server-side re-render of dynamic rows).
- Edit an existing child and save → updates, doesn't duplicate (catches missing `:id`).
- Remove an unsaved row, then submit → the row is absent from params entirely.
- Remove a persisted row, then submit → the destroy instruction reaches the server and takes effect.
- Add a row, leave it blank, submit → dropped, not persisted as an empty child.
- Remove every row → the form is still submittable and the server handles an empty collection.
- Switch a row's branch (friend↔guest) and submit → only the active branch's fields arrive.
- Back-navigate to the form after submitting → cached HTML doesn't resurrect removed rows or show stale errors.
- Render the form twice on one page (or in two frames) → the two don't interfere.

**System-test hygiene.** Never `sleep`; rely on Capybara's retrying matchers (`have_selector` polls, `sleep 2` is a fixed bet that fails under parallel CI where a worker gets a fraction of a core). Assert the DOM changed before asserting the database changed. Disable CSS transitions in the test environment so fading elements don't intercept clicks. And a Stimulus-specific flake worth pre-empting: **the test can click before the controller has attached.** The circulating fix is to expose a connected signal —

```javascript
connect() { requestAnimationFrame(() => { this.loadedValue = true }) }
```
```ruby
expect(page).to have_css("[data-controller~='nested-form'][data-nested-form-loaded-value='true']")
```

**[contested]** — it is test instrumentation in production code, which several sources would call a smell; the counter-argument is that it converts a flaky failure into a deterministic wait. Note this is a *decision*, not a rule: it only pays off once a real flake appears.

**Driver choice** is low-stakes: Selenium + headless Chrome is the Rails default and what both 37signals apps use; Cuprite is faster with a slightly divergent API; `capybara-playwright-driver` exists. Start with the default.

### 12. Anti-patterns

Each entry: what it looks like, why it's harmful, and what to do instead.

**The mega-controller.** One `session_form_controller.js` with add/remove rows, friend/guest toggling, score validation, a confirmation dialog and an autosave timer. Harmful because nothing in it is reusable, every change risks the others, the file has no natural stopping point (its name gives no reason to refuse new code), and it cannot be reasoned about locally — a bug in the toggle can only be understood by reading the whole file. Instead: several small controllers composed on the same element, named for behaviour.

**Business logic in Stimulus.** Deciding whether a player is an eligible friend, computing a winner, enforcing "scores must be integers". Harmful because it's a second implementation of a rule the server must enforce anyway (a client-only rule is not a rule — curl exists), it drifts from the server's version, and it can't be unit-tested where the rest of the domain logic lives. Instead: the server validates and re-renders; the client may *hint* (native `required`, `min`, `type=number`) but never decides. In all-aBoard the friend-eligibility rule already lives in `GameSessions::Create` and returns `:not_friends` — the form must not duplicate it.

**DOM queries everywhere.** `document.querySelector`, `getElementById`, CSS-class-based lookups inside controllers. Harmful in three compounding ways: it breaks the second instance of the component, it couples JavaScript to markup structure and design classes, and it makes the controller's dependencies invisible (a target attribute is documentation; a selector buried in line 40 is not). Fizzy's discipline here is measurable: **3 `document.querySelector` calls in the entire app**, all for global `<meta>` tags, versus 42 controllers using targets. Instead: declare targets; if you must query, scope to `this.element`; for per-event row lookup, `event.target.closest()`.

**Duplicated state.** The same fact in an instance field and in the DOM; a row count in JavaScript and in the markup; "selected" tracked in both a class and a value. Harmful because the two copies diverge on the first Turbo update, and the resulting bug is intermittent and load-order-dependent. Instead: pick the owner per §3 and delete the other copy.

**Global variables and app-level singletons.** `window.sessionForm = this`, module-level mutable state, an `EventBus` object. Harmful because it survives navigation when the DOM doesn't (so it goes stale), it makes two instances impossible, and it leaks. Instead: the DOM is the shared surface; use events for coordination.

**Fragile selectors.** `.btn-primary`, `div > div > .input`, `#player_1`, `nth-child`. Harmful because a restyle (daisyUI class change) or a markup tidy-up silently breaks behaviour with no error — the selector just matches nothing, and Stimulus outlets in particular treat an empty match as valid. Instead: `data-*-target` attributes are the contract; if you need a structural hook, use an attribute you own.

**Unnecessary abstractions.** A `BaseFormController` inherited by three controllers with one shared method; a "framework" of mixins; a config object with eleven options for a toggle. Harmful because the indirection costs more to read than the duplication cost to maintain, and it ossifies decisions before the third use case exists. Neither Fizzy nor Campfire has a shared Stimulus base class (Fizzy's only base class is `BridgeComponent`, from the native bridge library). The project's own Ruby convention says the same thing: *"Do not add an `ApplicationService` base class until there are 5+ services sharing the same delegation boilerplate"* (`app/AGENTS.md:42`). Apply the identical rule to JavaScript.

**Client-side templating.** Building rows, options or messages from strings/JSON in JavaScript. Harmful because rendering now exists in two languages with two sets of i18n, escaping and class names, and the validation-error path has no equivalent. Instead: `<template>` cloning (server-rendered) or a Turbo Frame/Stream.

**`element.submit()` instead of `element.requestSubmit()`.** Harmful because `submit()` bypasses validation *and* the submit event, so Turbo never sees it — the form does a full non-Turbo navigation and every `turbo:submit-*` handler is skipped. Both 37signals apps use `requestSubmit()` exclusively (6 controllers in Fizzy, several in Campfire). This is a small thing that produces very confusing bugs.

**Ignoring `disconnect()`.** Timers, observers, listeners and in-flight fetches that outlive the element. Harmful because Turbo navigations create and destroy controllers constantly, so a leak per visit becomes hundreds; and a stale timer can write into a DOM that no longer exists. Instead: every `connect()` acquisition has a `disconnect()` release, and prefer `data-action` so Stimulus does the bookkeeping.

**Hidden-but-enabled conditional fields.** Covered in §6.1; listed here because it's the highest-frequency *correctness* bug in interactive forms and it usually looks fine in manual testing.

### 13. Notes for AI coding agents

Everything above applies to humans too. These are the failure modes I'd specifically expect from an agent writing this code, based on what the patterns above make easy to get wrong. No respected source discusses agent-specific Stimulus failure modes, so this section is extrapolation — labelled as such — but the underlying failures are all documented.

**Never infer a data shape; declare it.** The recurring agent error is code that "handles" several possible shapes: `Array.isArray(x) ? x : Object.values(x)`, `typeof v === "string" ? JSON.parse(v) : v`, optional chaining stacked five deep. That defensiveness hides the real bug (the markup and the controller disagree) and makes the contract unknowable. The rules that remove the guessing:

- Configuration and state come in through `static values` with an explicit type. Types give guaranteed defaults (`[]`, `{}`, `0`, `""`, `false`), so no shape check is ever needed.
- `element.dataset.*` is **always a string**, or `undefined`. Compare against `"true"`, not `true`. Never do arithmetic on it without `Number()`.
- `event.params` is coerced by Stimulus (Number/String/Boolean/Object) — use it instead of reading `dataset` by hand.
- A fetch response is unknown data. Parse it at the boundary into the shape you declared, and fail loudly if it doesn't match. Don't sprinkle shape checks through the logic.
- Targets are elements, never data. `this.rowTargets` is an `Array` of elements (document order, guaranteed); `this.rowTarget` **throws** when absent, so guard with `this.hasRowTarget` when optional. Those three facts are the whole target interface — there's nothing to sniff.
- On the Rails side, the params shape is the contract: write it down (in the controller's strong-params call and in a request spec) and make the ERB produce exactly that. A dynamic form whose payload shape is only knowable by running the browser is unmaintainable.

**Scope every operation to the nested section that owns it.** The specific agent failure is a controller that operates on all rows when it should operate on one — usually via `this.element.querySelectorAll('.something')` or an index into a targets array. Countermeasures, in order: give the repeated section its own controller so `this.element` *is* the row; otherwise resolve the row from the event with `event.target.closest('[data-…-row]')`; never resolve a row by position. And remember the identifier rule: a row controller must not share its identifier with the container controller, or targets and bubbling events silently stop working.

**Name the owner of every piece of state before writing the controller.** If a change adds a fact to the page, say in the plan where it lives (server / value / DOM attribute / instance field / URL) and confirm it lives in exactly one place. This one habit prevents the majority of "works until you use it twice" bugs.

**Assume the DOM will be replaced.** Before finishing a controller, answer: what happens on a Drive visit, on back-navigation from cache, if a Turbo Stream replaces this region, if there are two of these on the page, and if `connect()` runs twice? For a form, the concrete checks are: does the server render the current state (so a 422 re-render is correct without JavaScript help), is anything acquired in `connect()` released in `disconnect()`, and does any behaviour depend on `connect()` running exactly once?

**Prefer the boring rung of the ladder.** An agent asked for "a dynamic form" will reach for fetch + client rendering because that's the shape of most JavaScript on the internet. The correction is to state the ladder as a requirement, and to require justification for any rung above "server renders it".

**Don't invent conventions where the repo has none.** all-aBoard has one scaffold Stimulus controller and no JavaScript lint, tests or house style. That vacuum invites an agent to import a mental model wholesale (a base controller, a utils folder, a testing framework). The right move is the minimum that ships the form, with any new tooling raised as an explicit decision.

### 14. Applying this to all-aBoard (S-03 session form)

**Current state, measured.** Turbo and Stimulus are loaded via importmap with **eager** controller loading (`app/javascript/controllers/index.js:3-4`). There is exactly one controller, the unused scaffold `hello_controller.js`. Six forms exist, all plain `form_with` with daisyUI classes, all relying on default Turbo Drive; there are no Turbo Frames, no Streams, no morphing configuration anywhere, no ViewComponents, no custom form builder, and `ApplicationHelper` is empty. There is no `spec/system`, no Capybara, no JS lint or test tooling. The single piece of Turbo-specific markup in the app is `data: { turbo_submits_with: 'Sending…' }` on the friend-request submit (`app/views/friendships/index.html.erb:21-22`), added as a double-click guard during S-02's implementation review.

**What S-03 needs.** A `/game_sessions/new` form with: a game `select` from the catalogue, the logger's own score, and a user-controlled number of player rows where each row is *either* a friend (select from accepted friends) *or* a guest (free-text name), plus an integer score, plus remove. On submit, `GameSessions::Create` receives `creator:, game_id:, creator_score:, players:` where each player is `{ type: 'friend', user_id:, score: }` or `{ type: 'guest', guest_name:, score: }`; the service filters the creator out of `players` defensively and returns `:created`, `:game_not_found`, `:not_friends` or `:invalid`. Edit reuses the same form and includes each existing row's `id` so `GameSessions::Update` can diff and re-notify.

**The consequential decision, and it's already made: no `accepts_nested_attributes_for`.** The plan routes participants through the service layer. That's a good fit here (the service owns notification side-effects and the friend-eligibility rule, which nested attributes cannot express), and it deletes several §7 hazards — no `_destroy`, no `allow_destroy`, no `reject_if`. It introduces one hazard the literature doesn't cover.

**The hazard: `players[][key]` is unsafe for these rows.** Rack builds an array-of-hashes from repeated `players[][…]` params by appending to the last hash until it sees a key that hash already has, at which point it starts a new one. That only produces correct rows when **every row submits the same keys**. This form's rows deliberately do *not*: a friend row has `user_id` and no `guest_name`, and (per §6.1) the inactive branch is `disabled`, so its fields submit nothing at all. Under `players[][…]`, one row's fields silently merge into the previous row's hash. So:

> **Use explicit numeric indices — `game_session[players][<index>][type]` — never `players[][type]`.**

Rails parses that into a hash keyed by index (not an array), which is exactly what `fields_for`-style permitting expects, and which the controller converts to the array the service wants. This is also why the index must stay numeric (§7.1).

**Recommended shape.** Two controllers, both small, plus one helper. The container owns add/remove; each row owns its friend/guest branch; the server owns everything else.

```erb
<%# app/views/game_sessions/_form.html.erb %>
<%= form_with model: @game_session, data: { controller: 'nested-form' } do |form| %>
  <div class="form-control">
    <%= form.label :game_id, class: 'label' %>
    <%= form.collection_select :game_id, @games, :id, :name, { prompt: 'Choose a game' },
          class: 'select select-bordered w-full' %>
  </div>

  <div class="form-control">
    <%= form.label :creator_score, 'Your score', class: 'label' %>
    <%= form.number_field :creator_score, class: 'input input-bordered w-full', required: true %>
  </div>

  <div data-nested-form-target="list">
    <% @player_rows.each_with_index do |player, index| %>
      <%= render 'player_fields', index: index, player: player, friends: @friends %>
    <% end %>
  </div>

  <template data-nested-form-target="template">
    <%= render 'player_fields', index: 'NEW_RECORD', player: nil, friends: @friends %>
  </template>

  <button type="button" class="btn btn-ghost" data-action="nested-form#add">Add player</button>
  <%= form.submit 'Log session', class: 'btn btn-primary',
        data: { turbo_submits_with: 'Saving…' } %>
<% end %>
```

```erb
<%# app/views/game_sessions/_player_fields.html.erb %>
<% base = "game_session[players][#{index}]" %>
<div class="card bg-base-200 p-4" data-controller="player-fields" data-nested-form-row>
  <%= hidden_field_tag "#{base}[id]", player&.id if player&.id %>

  <fieldset>
    <legend class="label-text">Player type</legend>
    <label class="label cursor-pointer">
      <%= radio_button_tag "#{base}[type]", 'friend', player.nil? || player.friend?,
            class: 'radio', data: { action: 'player-fields#typeChanged' } %>
      <span class="label-text">Friend</span>
    </label>
    <label class="label cursor-pointer">
      <%= radio_button_tag "#{base}[type]", 'guest', player&.guest? || false,
            class: 'radio', data: { action: 'player-fields#typeChanged' } %>
      <span class="label-text">Guest</span>
    </label>
  </fieldset>

  <fieldset class="disabled:hidden form-control"
            disabled="<%= 'disabled' unless player.nil? || player.friend? %>"
            data-player-fields-branch-param="friend"
            data-player-fields-target="branch">
    <%= select_tag "#{base}[user_id]",
          options_from_collection_for_select(friends, :id, :email, player&.user_id),
          include_blank: 'Choose a friend', class: 'select select-bordered w-full' %>
  </fieldset>

  <fieldset class="disabled:hidden form-control"
            disabled="<%= 'disabled' unless player&.guest? %>"
            data-player-fields-branch-param="guest"
            data-player-fields-target="branch">
    <%= text_field_tag "#{base}[guest_name]", player&.guest_name,
          class: 'input input-bordered w-full', placeholder: 'Guest name' %>
  </fieldset>

  <div class="form-control">
    <%= number_field_tag "#{base}[score]", player&.score,
          class: 'input input-bordered w-full', required: true %>
  </div>

  <button type="button" class="btn btn-ghost btn-sm" data-action="nested-form#remove">Remove</button>
</div>
```

```javascript
// app/javascript/controllers/nested_form_controller.js
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [ 'list', 'template' ]

  #index = Date.now()

  add() {
    const html = this.templateTarget.innerHTML.replaceAll('NEW_RECORD', this.#index++)
    this.listTarget.insertAdjacentHTML('beforeend', html)
  }

  remove({ target }) {
    target.closest('[data-nested-form-row]')?.remove()
  }
}
```

```javascript
// app/javascript/controllers/player_fields_controller.js
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [ 'branch' ]

  typeChanged({ target }) {
    this.branchTargets.forEach((branch) => {
      branch.disabled = branch.dataset.playerFieldsBranchParam !== target.value
    })
  }
}
```

Why this shape, point by point:

- **Two identifiers, not one.** `nested-form` never needs to know what a row contains, and `player-fields` never needs to know it's in a list. It also sidesteps the same-identifier scope trap, and `this.branchTargets` inside a row is automatically row-local — the leakage bug simply cannot be written.
- **`remove()` only removes DOM nodes.** With no nested attributes, an existing participant's removal is expressed by its `id` being absent from the submitted list, which `GameSessions::Update` already diffs. That convention must be stated in the plan, because "absent means delete" is invisible in the HTML.
- **`disabled` fieldsets** mean the inactive branch submits nothing, so the service receives exactly one of `user_id`/`guest_name` — which is what the model's `exactly_one_identity` validation and the DB CHECK constraint require. The alternative (hidden but enabled) sends both and turns a UI concern into a 422.
- **The server renders which branch is active** from `@player_rows`, so the validation-error re-render is correct with zero extra JavaScript. `@player_rows` should be built by the controller from either the submitted params (on re-render) or the persisted participants (on edit), which keeps the "no DB queries in views" rule (`app/AGENTS.md:44-47`) intact.
- **daisyUI classes stay in ERB.** No class names in JavaScript; visibility is derived from `:disabled` via Tailwind's `disabled:` variant, so a theme change can't break behaviour. (Verify that `disabled:hidden` on a `fieldset` produces the intended cascade in Tailwind 4 + daisyUI 5 before relying on it — if not, a `static classes` toggle is the fallback.)
- **`data-turbo-submits-with`** repeats the S-02 double-click guard, which matters more here because a double submit creates a duplicate session.

**Controller side.** Follow `FriendshipsController` — thin, service call, redirect with flash — and be explicit about the params conversion, because this is the boundary where shape bugs live:

```ruby
def create
  result = GameSessions::Create.call(creator: current_user, **session_params)
  # …dispatch on result.status; on failure re-render :new with @player_rows rebuilt from params
end

private
  def session_params
    permitted = params.require(:game_session).permit(:game_id, :creator_score, players: {})
    { game_id: permitted[:game_id],
      creator_score: permitted[:creator_score],
      players: players_from(permitted) }
  end

  def players_from(permitted)
    permitted.fetch(:players, {}).values.map do |row|
      row.permit(:id, :type, :user_id, :guest_name, :score).to_h.symbolize_keys
    end
  end
```

Three notes. Permitting `players` as an open hash and then permitting each row explicitly is deliberate: it keeps the per-row filter in one obvious place and avoids depending on the exact nested-permit semantics for a non-`*_attributes` key. `params.expect` is the Rails 8 idiom and is used elsewhere in modern examples, but it enforces shape and raises on a missing expected key — since a solo session submits **no** `players` at all, verify its behaviour with an empty payload before switching, or keep `require`/`permit`. And **write the request spec that posts this payload before writing the ERB** — with two rows at different numeric indices, one friend and one guest, and the inactive branches omitted. That single spec pins the entire contract between form and service, and it's the test that would catch every shape bug described in §7.

**What S-03 should *not* do.** No Turbo Frames or Streams (nothing here needs partial replacement — a redirect after create is correct and simpler). No morphing. No fetch, no JSON, no client-side rendering of options: the friend list and ~20-game catalogue are small enough to embed, per §9. No autosave. No client-side re-implementation of the friend-eligibility rule. No new JavaScript tooling (lint, jsdom) as part of this ticket. Adding Capybara for one system spec is defensible, but it is a tooling decision with CI cost and belongs in the plan explicitly rather than arriving as a side effect.

## Code References

Local (all-aBoard):

- `app/javascript/controllers/index.js:3-4` — eager controller loading; every controller ships on every page
- `app/javascript/controllers/hello_controller.js:1-7` — the only existing controller; unused scaffold
- `config/importmap.rb:3-7` — turbo-rails, stimulus, stimulus-loading pinned; controllers pinned as a directory
- `app/views/layouts/application.html.erb:2,21` — daisyUI `data-theme="abyss"`; no Turbo morph/refresh meta tags
- `app/views/friendships/index.html.erb:21-22` — `data-turbo_submits_with` double-click guard (only Turbo-specific markup in the app)
- `app/views/sessions/new.html.erb:4-24`, `app/views/users/new.html.erb:10-38` — established daisyUI form-control/label/input pattern
- `app/views/shared/_auth_card.html.erb:1-12`, `app/views/shared/_flash.html.erb:1-7` — shared view partial conventions
- `app/services/game_sessions/create.rb:5-14` — the params contract the form must produce; creator filtered from `players`
- `app/services/game_sessions/update.rb:55-66` — row `id` diffing on edit
- `app/models/game_session_participant.rb:8` and its `exactly_one_identity` validation — why exactly one of `user_id`/`guest_name` must be submitted, and why `score` must always arrive
- `app/AGENTS.md:44-47` — views render assigned ivars only, no DB access in views
- `app/AGENTS.md:38-42` — "no base class until 5+ users" rule, directly transferable to JS
- `spec/AGENTS.md:14-28` — spec layout; request specs are the primary integration surface
- `context/changes/log-session-confirm-flow/plan.md:339-357` — the planned `nested-form` contract this guide refines

Reference repositories (external clones; commits in the evidence-base table):

- `fizzy: app/javascript/controllers/morph_guard_controller.js:8-15` — dynamic `data-turbo-permanent` around an in-progress edit
- `fizzy: app/javascript/controllers/form_controller.js:26-28,65-71` — shared form controller: `requestSubmit`, `reset`, `cancel`
- `fizzy: app/javascript/helpers/form_helpers.js:3-9` — why autosave requests JSON: the Turbo Stream response would morph the form being typed in
- `fizzy: app/javascript/controllers/auto_save_controller.js:11-13,23-27` — debounced save; flush on `disconnect()`
- `fizzy: app/javascript/controllers/multi_selection_combobox_controller.js:120-126` — `<template>` cloning with `removeAttribute("id")`
- `fizzy: app/javascript/controllers/filter_form_controller.js:6-8` — scoped `this.element.querySelectorAll` for a checkbox group
- `fizzy: app/javascript/controllers/details_controller.js` — native element plus the delta only
- `fizzy: app/helpers/forms_helper.rb:2-10` — composing `data-controller` from a Ruby helper
- `fizzy: test/system/card_refresh_test.rb:22-37` — system test asserting an in-progress edit survives a broadcast refresh
- `campfire: app/javascript/controllers/turbo_streaming_controller.js:3-10` — drop the container `id` on submit-start to avoid stream/response races
- `campfire: app/helpers/messages_helper.rb:70-84` — long `data-action` strings assembled in Ruby
- `campfire: app/javascript/controllers/composer_controller.js:115-125` — optimistic insert then `requestSubmit()`
- `campfire: app/javascript/helpers/dom_helpers.js:27-31` — `ignoringBriefDisconnects` guard for reconnect churn
- `stimulus: docs/reference/lifecycle_callbacks.md:26-90` — callback set, ordering, instance reuse
- `stimulus: docs/reference/controllers.md:73-88,90-115,202-251` — nested scope exclusivity, multiple controllers, `dispatch()`
- `stimulus: docs/reference/values.md:55-105,149-151` — types, defaults, `valueChanged` at initialisation
- `stimulus: docs/reference/targets.md:53-59,117-120` — target properties; observer pause during target callbacks
- `stimulus: docs/reference/outlets.md:32,180-197` — global outlet selectors; target must carry `data-controller`
- `stimulus: docs/reference/actions.md:55-66,157-172,305-344` — default events, options, params
- `turbo: src/core/snapshot.js:55-60` — `#id[data-turbo-permanent]`: both attributes required
- `turbo: src/core/morphing.js:6-9,67-100` — morph events; permanent nodes skipped
- `turbo: src/observers/cache_observer.js:2-23` — `data-turbo-temporary` removal before caching
- `turbo: src/core/drive/form_submission.js:127-176,206-212` — submit events, redirect requirement, stream acceptance
- `turbo-rails: app/helpers/turbo/drive_helper.rb:62-72` — `turbo_refreshes_with` defaults (`replace`, `scroll: reset`)

## Architecture Insights

**The convention is in the code, not in a document.** Neither 37signals app publishes JavaScript conventions: Fizzy's `AGENTS.md` covers commands, deploy and architecture and hands style off to a Ruby-only `STYLE.md`; Campfire has no conventions doc at all. Both are nevertheless extremely consistent, because the codebase is the guide — *"try to find similar code elsewhere to look for inspiration"* (`fizzy: STYLE.md:8`). For a repo with **one** scaffold controller, that mechanism is unavailable, which is precisely why F-04 exists: all-aBoard needs the first two controllers to be exemplary, because they will be the corpus every later agent imitates.

**Declarative-first is the deepest shared pattern.** Both apps push wiring into HTML (`data-action`, including Turbo lifecycle events) rather than into `connect()`, to the point where Campfire has one `addEventListener` in a controller and zero `removeEventListener`. Complex action strings then get assembled in Ruby helpers, keeping them server-side, testable and out of the ERB. That's a stronger convention than any naming rule, and it's the one that makes controllers survive Turbo without cleanup code.

**Small-and-many beats large-and-few, but not uniformly.** Fizzy's median controller is 31 lines and its largest is 282; Campfire's three biggest hold 54% of its JavaScript. Complexity concentrates where the product is genuinely interactive, and everything else is a few lines. The reviewable signal isn't a line limit — it's whether a large controller corresponds to something genuinely hard.

**Outlets are a niche tool.** 3/69 and 2/33 in production, always for a one-to-one "call a method on that thing" relationship. Events plus shared DOM carry the rest. Any design that needs many outlets is probably fighting the DOM's own structure.

**Morphing is opt-in and has a real cost budget.** Turbo does not protect in-progress input during a morph (deliberately, per `hotwired/turbo#1195`), and Stimulus values get overwritten by the server's version without `connect()` re-running (`#1210`). Fizzy pays that cost consciously with `morph_guard`, JSON autosave, `turbo:before-cache` dialog closing and morph-refresh hooks — a whole supporting kit. all-aBoard has none of that kit and needs none of it, which is an argument for keeping morphing off until something concrete demands it.

### Notable absences (what the evidence does *not* show)

Absence is a finding, and these are the ones that changed my conclusions or should stop a later reader from over-claiming.

- **No published JavaScript conventions at 37signals.** Fizzy's `AGENTS.md` covers commands, deploy and architecture and hands style to a Ruby-only `STYLE.md`; Campfire has no conventions doc at all. Zero rules about Stimulus, Turbo, forms or ERB in either. The circulating "37signals Stimulus style guide" gist is machine-generated from the codebase and already stale (52 controllers vs 69 on `main`). Cite the code.
- **No JavaScript unit tests in either app.** No Jest, no Vitest, no jsdom, no `*.test.js`. Stimulus behaviour is covered by system tests (4 in Fizzy, 3 in Campfire) or not at all.
- **No shared Stimulus base class or mixin** in either app. Fizzy's only base class is `BridgeComponent`, from the native-bridge library.
- **`*ValueChanged` is nearly unused in production** — 1/69 in Fizzy, 0/33 in Campfire. See §3 for why that qualifies the recommendation rather than voiding it.
- **`fields_for` and `insertAdjacentHTML`: zero occurrences in Fizzy.** Its dynamic-field needs are met by `<template>` cloning in the combobox controllers. So the nested-form pattern in §7 is community-canonical, **not** 37signals-attested — the strongest thing production code says about it is that `<template>` cloning plus `removeAttribute("id")` is how they clone form fields.
- **`data-turbo-temporary`: zero occurrences in Fizzy.** They clean up explicitly with `turbo:before-cache@document->dialog#close` actions instead. Both are documented; the production preference is the explicit one.
- **Campfire has no morph handling at all** — no `turbo:morph*` listeners, no `turbo:before-cache`, no morph-related controller logic. It predates Turbo 8 morphing and needs none of the kit in §10. That is direct evidence that an app without morphing does not owe anything to that section.
- **No respected source discusses AI-agent-specific Stimulus failure modes.** §13 is extrapolation from documented human failures, and is labelled as such.
- **No source enumerates the edge cases to test in dynamic nested forms.** The list in §11 is derived from documented failures — this guide's contribution, not received wisdom.
- **No respected source recommends Web Components over Stimulus for form behaviour.** The alternatives sources actually name are plain HTML/CSS, a Turbo round-trip, and (for genuinely heavy client state) an embedded React/Svelte island. If a later rule or plan proposes Web Components here, it is an original position and should be argued, not cited.
- **No source recommends `application.getControllerForElementAndIdentifier`**, and most don't mention it. Outlets exist because it used to be the workaround.
- **`turbo_power`, `nested_form_fields` and `stimulus_reflex` did not surface** in any current nested-forms discussion; `cocoon` is uniformly described as unmaintained. The field has converged on plain Stimulus and Turbo Streams.
- **One published article I could not locate** ("edit, delete and reposition for nested forms", referenced by Rails Designer's own related-articles list) is likely the only treatment of *reordering* nested rows. If S-03 ever needs drag-to-reorder participants, that is unresearched territory.

**This project's biggest form risk is param shape, not JavaScript.** The service layer already owns notifications and friend-eligibility, so the interactive part is genuinely small (two controllers, ~25 lines total). What can silently break is the payload: index collisions, non-numeric indices, `players[][…]` merging heterogeneous rows, and both branches of a row submitting. All four are catchable by one request spec, which makes that spec the highest-leverage artifact in S-03 Phase 3.

## Historical Context (from prior changes)

- `context/archive/2026-06-07-tailwind-daisyui-setup/plan.md:11,41` — the frontend slice deliberately excluded custom Stimulus for daisyUI components; flash dismissal was left to Turbo with "no JS needed for MVP". So the absence of controllers today is a decision, not an oversight.
- `context/archive/2026-07-12-email-password-auth/plan.md:131` — established the daisyUI form idiom (`card`, `form-control`, `input input-bordered`, `btn btn-primary`) that the session form should follow.
- `context/archive/2026-07-12-email-password-auth/reviews/plan-review.md:71` — flagged at the time: "Importmap + Stimulus overhead for form validation not assessed". F-04 is the assessment.
- `context/archive/2026-07-14-mutual-friend-circle/reviews/impl-review.md:50` — `data-turbo_submits_with` added as a double-click guard; Turbo disables the submitter by default. Direct precedent for the session form's submit button.
- `context/archive/2026-07-14-mutual-friend-circle/research.md:68-96,138-146` — the participant schema (single table, nullable `user_id` or `guest_name`) and the decision to defer a generic `Notification` until S-03 had a second consumer. Both shape the params the form must produce.
- `context/changes/log-session-confirm-flow/plan.md:23-24,339-357` and `plan-brief.md:25,57` — the plan already specifies `<template>` + Stimulus (~20 lines) and flags "first Stimulus controller, no prior art in codebase" as a risk. This guide's §14 is the concrete answer to that risk, with two corrections to the plan's contract: use explicit numeric indices rather than `Date.now()` alone, and split the row's friend/guest toggle into a second controller identity.
- `context/foundation/roadmap.md:158,182` — F-04 gates S-03 form work: *"Do not continue form work until F-04 lands."*
- `context/foundation/lessons.md` — no forms/JS lessons yet; the "never present findings before all sub-agents complete" entry is process-level and was honoured here.

## Related Research

No prior research artifact covers Stimulus, Hotwire or forms — this is the first. Adjacent artifacts: `context/changes/log-session-confirm-flow/plan.md` (the consumer of this guide), `context/archive/2026-06-07-tailwind-daisyui-setup/plan.md` (frontend stack decisions), `context/foundation/test-plan.md:87-88` (records that Capybara is not configured).

## Open Questions

1. **Does `disabled:hidden` on a `<fieldset>` behave as intended in Tailwind 4 + daisyUI 5?** The pattern is from a Tailwind 3-era article. If the variant doesn't apply to `fieldset` as expected, the fallback is a `static classes` toggle in `player-fields` — same architecture, one more attribute. Worth a five-minute check before the plan commits to it.
2. **Is "absent from `players[]` means delete" the intended edit semantics** in `GameSessions::Update`, or should removal be explicit? The service diffs by `id`, which implies absence-means-delete, but that convention should be stated in the plan and covered by a spec, because it is invisible from the HTML.
3. **Does S-03 add Capybara?** One system spec would cover add/remove/toggle end to end; the cost is a browser in CI and a new flake surface. Explicit decision needed, not a side effect.
4. **Where do the two controllers' conventions get recorded** so the third controller follows them — `app/AGENTS.md`, a new `app/javascript/AGENTS.md`, or a Cursor rule? This guide's Deliverable B is the input to that choice.
5. **Should the `players` param key become `players_attributes`** to inherit Rails' nested-params handling for free, even without `accepts_nested_attributes_for`? Probably not worth the misdirection, but it would make the permit call more conventional.
6. **`played_at` drift, noticed in passing.** The S-03 plan specifies a `played_at` column, a presence validation, a factory default and its display in the session list and notification cards (`context/changes/log-session-confirm-flow/plan.md:102,126,164,235,377`), but Phases 1–2 shipped without it: no migration, no column in `db/schema.rb`, no reference anywhere in `app/`. Not a forms question, but the views this guide feeds into are specified to render a date that doesn't exist yet — resolve before Phase 3 rather than mid-form.
7. **Empty-state and solo sessions.** The plan allows a logger-only session; the form should therefore render zero player rows initially and remain submittable. Confirm that's the intended UX rather than "at least one player".

## Deliverable 1: Code-review checklist

Interactive-form review, in the order that finds bugs fastest.

**Params and server contract**
- [ ] Every dynamically added row uses a **unique, numeric** index; no `players[][key]` / `x_attributes[][key]` forms.
- [ ] Strong params permit exactly the submitted shape, including `:id` for existing rows (and `:_destroy` if nested attributes are used).
- [ ] A request spec posts the payload the DOM actually produces, with ≥2 rows and at least one inactive branch.
- [ ] Validation failure re-renders with the user's rows and branch states intact, at status 422.
- [ ] No business rule is enforced only in JavaScript.

**HTML wiring**
- [ ] Every target/value/class used in JS is declared in `static` and present in the markup, with matching camelCase/kebab-case.
- [ ] Values and classes are on the same element as `data-controller`.
- [ ] A repeated section's controller identifier differs from its container's.
- [ ] No design/utility CSS class is used as a JS selector; no `nth-child`, no id-based coupling that isn't generated per instance.
- [ ] Conditional field groups are `disabled` (ideally a `<fieldset>`), not merely hidden; `required` matches visibility.
- [ ] Radio/checkbox groups are wrapped in `<fieldset>` with `<legend>` as the first child; triggers use `aria-controls`.
- [ ] Cloned `<template>` content contains no duplicate `id` (or ids are index-generated by `fields_for`).

**Controller code**
- [ ] Does one thing; composed with siblings rather than absorbing their concerns.
- [ ] Named for behaviour, not for the page or feature.
- [ ] No `document.querySelector` / `getElementById`; row lookups use `event.target.closest(...)` or a per-row controller.
- [ ] No state duplicated between an instance field and the DOM; every fact has one owner.
- [ ] No HTML built from strings; `<template>` or a server round-trip instead.
- [ ] No shape sniffing (`Array.isArray`, `typeof`, defensive `JSON.parse`); values are typed, `dataset` reads are compared as strings.
- [ ] Optional targets guarded with `has*Target`.
- [ ] Derived rendering lives in `valueChanged` / `targetConnected`, not in a `connect()` loop.
- [ ] Everything acquired in `connect()` is released in `disconnect()`; listeners prefer `data-action`.
- [ ] `connect()` is safe to run twice.
- [ ] `requestSubmit()`, never `submit()`.

**Resilience**
- [ ] Correct if the region is replaced by a Turbo Frame/Stream, and if `connect()` re-runs.
- [ ] Correct with two instances on one page.
- [ ] Transient UI (dialogs, previews, flashes) is reset at `turbo:before-cache` or marked `data-turbo-temporary`.
- [ ] If morphing is in play: in-progress input is protected (dynamic `data-turbo-permanent` + `id`), the form resets on `turbo:submit-end`, and any UI-state attribute that must not be overwritten is vetoed via `turbo:before-morph-attribute`.

## Deliverable 2: Candidates for Cursor rules

These are falsifiable — a reviewer or a grep can decide whether the code complies — which is the property a rule needs. Ordered with prohibitions first, since agents weight early lines more heavily.

**Hard prohibitions**
1. Never use `document.querySelector`, `document.querySelectorAll` or `getElementById` inside `app/javascript/controllers/**`. Use targets, `this.element.querySelector`, or `event.target.closest(...)`.
2. Never build HTML from strings or JSON in a Stimulus controller. Clone a server-rendered `<template>`, or render server-side via Turbo.
3. Never call `form.submit()`; call `form.requestSubmit()`.
4. Never enforce a business rule only in JavaScript. The server validates and re-renders.
5. Never keep authoritative state in a controller instance field. State lives in the DOM (attributes/values), the URL, or the server; instance fields hold only non-serialisable objects, timers and observers, all released in `disconnect()`.
6. Never give a repeated section the same `data-controller` identifier as its container.
7. Never use `players[][key]`-style index-less array params for rows with optional or conditionally-disabled fields; always render explicit numeric indices.
8. Never hide a conditional field group without disabling it.
9. Never add a base class, mixin or shared abstraction for Stimulus controllers until 5+ controllers share the same boilerplate (mirrors the existing `ApplicationService` rule).
10. Never use inline `<script>` for behaviour.

**Required practices**
11. Declare every value with an explicit type in `static values`; read configuration through values, never by parsing `dataset` by hand or inferring shapes at runtime.
12. Treat `element.dataset.*` as a string always (compare to `"true"`, coerce with `Number()`).
13. Guard optional targets with `has*Target`.
14. Put derived rendering in `[name]ValueChanged` or `[name]TargetConnected`, not in a `connect()` loop over targets.
15. Prefer `data-action` in markup over `addEventListener` in `connect()`; if you must attach manually, remove in `disconnect()`.
16. Indices for dynamically added rows must be unique and numeric (monotonic counter seeded from `Date.now()`).
17. Name controllers for behaviour (`nested-form`, `auto-submit`, `player-fields`), not for pages or features.
18. Keep CSS class names in HTML via `static classes`, not hardcoded in JavaScript.
19. Every new interactive form gets a request spec that posts the exact payload the DOM produces, including a multi-row case.
20. Follow the escalation ladder — HTML → CSS → Turbo Frame → Turbo Stream → Stimulus attribute toggling → client rendering — and justify anything above "server renders it" in the plan.
21. Prefer events (`this.dispatch`) or shared DOM over outlets for controller communication; do not query or mutate another controller's DOM.
22. Every `data-*-target`, `-value` and `-class` attribute referenced in JS must exist in markup and be declared `static` (and vice versa: no unused declarations).

**Project-local facts worth encoding**
23. Ruby in this repo prefers single quotes; JavaScript controllers follow the existing file's style (no linter configured — match `hello_controller.js`/neighbouring files rather than inventing a style).
24. Views render assigned ivars only — build `@player_rows`, `@friends`, `@games` in the controller, never query from ERB.
25. Forms use the daisyUI idiom already established (`form-control`, `label`/`label-text`, `input input-bordered w-full`, `btn btn-primary`), and destructive/creating submits carry `data-turbo-submits-with`.

## Deliverable 3: Recommendations that should NOT become Cursor rules

These require judgement; as fixed rules they'd be wrong often enough to teach an agent to ignore the rules file.

1. **"Keep controllers under N lines."** The real norm is a lopsided distribution, not a cap. Fizzy's biggest controller is 282 lines and correct. A hard limit produces artificial splits that are harder to read than the original. Review the *reason* a controller is large.
2. **Which round-trip mechanism to use (Frame vs Stream vs full render).** Depends on what must change, what must stay, latency tolerance and whether a no-JS path is needed. State the ladder as a rule; leave the rung to judgement.
3. **Whether to use `accepts_nested_attributes_for` or a service/REST-per-child design.** Atomicity, side-effects and endpoint count all matter. Even the sources that argue hardest for one publish the other.
4. **Whether to enable Turbo morphing.** A real trade-off with a supporting kit (permanence guards, JSON autosave, attribute vetoes) whose cost only pays off for broadcast-heavy UI. Respected sources actively disagree.
5. **Whether to embed data in HTML or fetch it.** Quantitative, and the threshold moves with payload size, staleness tolerance and privacy. "Tens: embed; thousands: don't" is guidance, not a rule.
6. **Outlets vs events for a specific pair of controllers.** The decision rule (does the emitter care who listens? is the audience known and singular?) needs applying, not asserting; published orderings conflict.
7. **Whether to add Capybara / system tests to a given change.** Real CI cost and a real flake surface, weighed against the risk of the specific interaction. Per-change decision.
8. **Whether to unit-test a controller in jsdom/Vitest.** Depends entirely on whether meaningful logic was extracted. As a blanket rule it produces tests that assert against fixture HTML nobody ships.
9. **Whether to expose a `connected` value for test synchronisation.** Production instrumentation for tests; worth it once a real flake appears, noise before that.
10. **When to extract logic to a plain module.** "Extract when it has its own vocabulary and no DOM dependency" is a judgement call; premature extraction is its own anti-pattern.
11. **Whether a controller is "reusable enough".** Generalising before the second use case invents requirements. Fizzy has both highly generic controllers and frankly domain-specific ones.
12. **Accessibility beyond the mechanical parts.** `<fieldset>`/`<legend>` placement and `disabled` semantics are rule-shaped; live-region announcements, focus management after dynamic insertion, and whether `aria-disabled` beats `disabled` in a given widget need a human.
13. **Naming an individual controller.** "Name for behaviour" is a rule; whether this one is `player-fields`, `participant-row` or `player-type` is taste, and consistency with neighbours beats any external standard.


