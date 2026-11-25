---
source_checksum: 984d3b7bada75027
distilled_at_sha: cf64a3d8f7ef3e3137b983ecedac825dcf82a0b3
---
<!-- Auto-generated from docs.gitlab.com by gitlab-ai-principles-distiller — do not edit manually -->

> **Prerequisite:** If you haven't already, also read .ai/principles/distilled/frontend-vue.md - it contains foundational rules that apply to all frontend work.

# Frontend Accessibility Principles

## Checklist

### Semantic HTML

- Prefer semantic HTML elements over `div`/`span` with ARIA roles (e.g., use `<button>` not `<div role="button">`, `<a>` not `<div role="link">`)
- DO NOT use `role` attributes when a native HTML element with the equivalent implicit role exists
- Replace `div`/`span` elements with semantic equivalents like `p`, `button`, `time`, `article`, `ol`/`ul`, `table`, etc.
- Ensure heading levels are not skipped and are nested correctly
- Ensure only one `h1` element exists per page
- Make the `h1` express the page's primary purpose and `h2` headings support it. An `h2` may precede the primary `h1` for navigation, alerts, or banners, but must not be visually more prominent.

### Accessible Names

- Ensure every form input (`text`, `textarea`, `select`, `checkbox`, `radio`, `file`, `toggle`) has an associated `<label>`
- Group checkboxes and radio inputs in a `fieldset` with a `legend`; with `GlFormGroup`, passing only `label` renders a `fieldset`/`legend`, while `label` plus `label-for` renders a `label` pointing at the input with that ID
- Ensure every button and link has visible text or an `aria-label` when no visible text is present
- Give each button and link a unique, descriptive accessible name that does not repeat.
- Ensure every `<img>` has an `alt` attribute (empty `alt=""` for decorative images)
- Keep `alt` attribute text under approximately 150 characters
- Ensure `<fieldset>` has `<legend>` as its first child
- Ensure `<figure>` has `<figcaption>` as its first child
- Ensure `<table>` has `<caption>` as its first child
- Provide a row header for every table row.
- Ensure every chart has both a short and a long description (per W3C complex image guidance)
- Ensure buttons and links have accessible names descriptive enough to be understood in isolation (e.g., "Submit review" not "Submit")
- Use `gl-sr-only` class to visually hide labels that must remain accessible to screen readers
- Know the accessible-name computation order the browser uses when several names are present (`aria-labelledby` → `aria-label` → `alt`/`legend`/`figcaption`/`caption` → `title`); this is the resolution order, not authoring advice — DO NOT add `aria-label` where a descriptive `alt` already provides the name

### Icons

- Ensure non-decorative icons (those conveying information) have an `aria-label`
- Ensure clickable icons use `<gl-button icon="..." />` not `<gl-icon />` with a click handler
- Ensure icon-only buttons have an `aria-label`
- DO NOT add `aria-hidden="true"` to `<gl-icon>` — it hides icons from screen readers by default
- Hide decorative images from screen readers using `alt=""` on `<img>`, or `role="img"` + `alt=""` on inline SVGs

### Hiding Elements

- Use `.gl-sr-only` to hide an element from sighted users only, `aria-hidden="true"` to hide it from screen readers only, and `display: none`, `visibility: hidden`, or the `hidden` attribute to hide it from both

### ARIA Usage

- DO NOT use `aria-*`, `role`, or `tabindex` when semantic HTML provides equivalent accessibility
- Use ARIA only for UI patterns without semantic HTML equivalents (e.g., modals, tabs, custom dropdowns)
- Ensure all custom ARIA widget patterns comply with WCAG

### Keyboard Navigation & Focus

- Ensure all interactive elements are reachable via <kbd>Tab</kbd> and have a visible focus state
- Ensure elements with tooltips are focusable via <kbd>Tab</kbd>
- Move focus into a modal dialog when it opens and back to the trigger when the dialog or drawer closes; choose a fallback focus target when the previously focused element is removed.
- When adding `:hover` styles, add matching `:focus-visible` styles for keyboard users (prefer `:focus-visible` over `:focus`, which also applies styles when a mouse click focuses the element)
- DO NOT remove an element's `outline` without providing an alternative visible focus indicator (e.g., `box-shadow`)
- Ensure <kbd>Tab</kbd> and <kbd>Shift-Tab</kbd> move only between interactive elements, not static content

### Tooltips

- DO NOT put interactive content (links, buttons, inputs, elements with `tabindex` or click listeners) inside a tooltip — keyboard users cannot reach it (WCAG 2.1.1); use `GlPopover` instead. Enforced as an error by the `@gitlab/vue-no-interactive-content-in-tooltip` ESLint rule.
- Manually review tooltip cases the ESLint rule does not detect: custom components rendering focusable elements, runtime content (dynamic components, `v-html`), content passed via props or slots, `v-gl-tooltip`/`has-tooltip`/`data-toggle="tooltip"` with HTML in `title`/`data-title` (including HAML and helpers), and elements made interactive via JavaScript handlers
- When migrating a tooltip violation to `GlPopover`, set `triggers="click"` (the default `hover focus` can close the popover before users reach its content), make the trigger keyboard-focusable (e.g., `GlButton`), and keep a tooltip only for plain non-interactive text
- DO NOT add new files to `.eslint_todo/`; if a tooltip violation cannot be fixed, disable ESLint for that single violation
- Put the tooltip on the element that already takes focus (usually the enclosing link or button), using a placement modifier such as `.topleft` when the tooltip should sit over the text; DO NOT put `v-gl-tooltip`/`GlTooltip` on static elements (`span`, `strong`, `h3`) that keyboard users cannot focus
- Forward a focusable host's focus to a tooltip on the text inside it only when the tooltip must anchor to the text of a full-width host and no placement modifier works; use `showGlTooltip`/`hideGlTooltip` from `~/vue_shared/utils/tooltips` on the host's `@focus`/`@blur` (DO NOT use `@focusin`/`@focusout`, which bubble and open two tooltips)
- Add `tabindex="0"` with `focus-visible:gl-focus` to a static element with a tooltip only when the tooltip holds information available nowhere else
- Use `GlPopover` when the tooltip content is a link or an action

### `tabindex`

- DO NOT use `tabindex="0"` on interactive elements (`<gl-link>`, `<gl-button>`) — they are already tab-accessible
- DO NOT use `tabindex="0"` on static/non-interactive elements just to make them readable by screen readers
- Add `tabindex="0"` to a container whose content exceeds its calculated height and whose CSS permits scrolling (`overflow: auto` or `scroll`), so keyboard users can focus and scroll it.
- DO NOT use positive `tabindex` values (`tabindex="1"` or greater)
- DO NOT use `tabindex="0"` to make a `div`/`span` interactive — use a semantic interactive element instead

### Testing & Tooling

- Rely on the CI accessibility checks (Storybook tests use `axe-playwright` and run on Vue/JS changes, blocking merges on violations); the repository's `axe-linter.yml` maps Pajamas components to native HTML. Humans can additionally install the [axe Accessibility Linter](https://marketplace.visualstudio.com/items?itemName=deque-systems.vscode-axe-linter) VS Code plugin for real-time editor feedback.
- Add Storybook stories covering all component states for new Vue components and ensure Storybook accessibility tests pass before integration
- Include feature tests using `axe-core-gem` for complete user journeys covering HAML, Vue, and JS
- Prioritize accessibility feature tests for mission-critical user journeys, high-traffic pages, new features, and complex UI interactions; prefer deep coverage of key scenarios over broad shallow coverage of every page
- Use axe DevTools browser extension during code review to validate accessibility on any page
- For Vue/JS files: apply linting + Storybook tests + feature tests
- For HAML files: apply feature tests + browser extension (linting not supported)
- Place accessibility feature specs under `spec/features/accessibility/<stage>/<feature>/`, named after the E2E test case they follow (e.g., `add_new_branch_rule_spec.rb`)
- Generate accessibility specs for golden user journeys from the YAML definitions in `config/accessibility_journeys` (follow its README)
- Use the `be_axe_clean` matcher for accessibility assertions; scope to `#content-body` for full-page tests or to a specific section selector for partial-page tests
- DO NOT include elements that appear on every view (breadcrumbs, main navigation) in feature spec scans — they have their own feature specs
- DO NOT use `wait_for_requests` before an axe scan — wait for a page-specific element that represents the rendered state instead
- Activate hidden regions (inactive menus, dialogs) before running `be_axe_clean` — axe does not scan hidden regions automatically
- Add `be_axe_clean` assertions for both the empty state and the default view when a view has an empty state
- Add the first `be_axe_clean` assertion early in a user-journey test, before any user interactions are simulated
- Add `be_axe_clean` assertions after significant page structure changes (e.g., a dialog opens or a new section renders)
- Use `with_minimum_impact` (with a required non-blank `because:` argument linking a tracking issue) only when bootstrapping coverage on an existing area; remove or tighten the threshold once critical violations are resolved
- Use `.skipping :'link-in-text-block'` to suppress the known `link-in-text-block` violation until the design system fixes it in `GlLink` (tracked in design.gitlab.com issue 1444)
- Create a follow-up issue labeled `accessibility` and `accessibility::intake` when fixing an accessibility test error requires global changes

## Authoritative sources

For the full picture, see:

- doc/development/fe_guide/accessibility/_index.md
- doc/development/fe_guide/accessibility/best_practices.md
- doc/development/fe_guide/accessibility/feature_tests.md

