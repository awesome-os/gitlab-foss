# Merge Request Guidelines

## Merge Request Description

Base the description on a template from `.gitlab/merge_request_templates/`. List that directory and choose the most specific template that matches the change; the template names indicate their purpose. When no specific template fits, or when unsure, use `Default.md`. Read the chosen template file and keep all of its sections: fill in each section, or state briefly why it does not apply, rather than deleting it. Treat HTML comments in the template as instructions to follow, then remove them from the final description. Read the template even when you pass the description with `glab mr create --description`, because that command does not apply the template.

In the "How to set up and validate locally" section, describe how you checked the change in the product, the same way a user experiences it:

- A UI change: use the page in a browser. Put before and after screenshots or a short recording in the "Screenshots or screen recordings" section when the template has one.
- An API change: call the API the way a client does. Show the request and the response.
- A CLI, Git, or runner change: run the command a user runs. Show the output.

Write the steps so a reviewer can repeat them, such as enabling a feature flag, running commands in the Rails console, or visiting a page. Do not list steps to run specs or linters; CI runs them. Any environment is fine: GDK, GDK-in-a-box, Caproni, a review app, or another setup. When the MR has no user-facing change, write one line that says so. When you cannot run the product, for example in a CI job without GDK or a browser, write that you did not validate it and list the steps for a reviewer. Never describe a check you did not run.

If there are related issues, add their URLs to the description of the merge request under the heading `References`.

Add quick commands at the bottom of the description:

- Add a line with `/assign me` so the MR is assigned to the author.
- Add a line with `/milestone <milestone>` where the `<milestone>` corresponds to the milestone in the file `./VERSION`
  - For example, if `./VERSION` contains 18.11.0-pre, use the milestone `%18.11`.

## Pre-submission readiness checklist

Before opening a merge request, verify each predicate that applies to your change. Each item states the action; follow the linked detail for the how.

### Review

- Before opening the merge request, review local changes using the reviewer sub-agent and fix findings that matter.

### Changelog

- Add a changelog trailer for any user-facing change, or explicitly decide it is unnecessary. Use the `--changelog` flag on `git commit` or add a `Changelog:` trailer.
- Detail: `.ai/principles/distilled/code-review.md` and `doc/development/changelog.md`.

### Tests

- Add or update tests for code changes. Recommended for documentation changes that ship code examples.
- Detail: `.ai/principles/distilled/testing-rspec.md` (backend, RSpec) and `.ai/principles/distilled/testing-jest.md` (frontend, Jest).

### Documentation

- Update documentation when behavior, API surface, configuration, or UI changes.
- Detail: `.ai/principles/distilled/documentation.md`.

### Validation evidence

- Attach validation evidence for every user-facing change, not only for visible UI.
- To attach a file, upload it to the MR's target project with `POST /projects/:id/uploads` (for example `glab api --method POST projects/:id/uploads --form "file=@before.png"`) and put the returned `markdown` field in the description. In a fork, replace `:id` with the URL-encoded path of the target project, such as `gitlab-org%2Fgitlab`.

### Application Security review

- Request Application Security review for changes touching authentication, session handling, dependency lockfiles, or other security-sensitive paths.
- Detail: `.ai/principles/distilled/security.md` and `.ai/principles/distilled/code-review.md`.

### Database review

- Request database review for migrations, schema changes, or query changes against large tables.
- Detail: `.ai/principles/distilled/database-fundamentals.md`, `.ai/principles/distilled/database-migrations.md`, and `.ai/principles/distilled/database-schema.md`.

### Translation

- Do not add hard-coded user-facing strings. Wrap them with the `_()`, `s_()`, or `n_()` externalization helpers (in JavaScript, `__()`, `s__()`, `n__()`) so they can be translated.
- Detail: `doc/development/i18n/externalization.md`.

### Feature flag

- Put non-trivial behavior changes behind a feature flag and define a rollout plan.
- Detail: `.ai/principles/distilled/feature-flags.md`.

### Milestone

- Set the milestone before merging, when the MR is likely to land in the current milestone.
- Detail: `.ai/principles/distilled/code-review.md` (Approval Requirements).

### MR type label

- Required: apply exactly one MR type label before merge. MR labels are reviewed for SOX compliance, so do not guess. When unsure, check the handbook definitions linked below.
  - `type::bug`: fixes for defects in shipped code. Fixes behind a default-off feature flag are `type::feature`.
  - `type::feature`: new features, feature changes, and improvements.
  - `type::maintenance`: refactors, engineering tooling, dependency upgrades, feature flag removal, spec-only changes, and documentation updates. New documentation and new feature flags take the type of the change they belong to. Examples may include: CI configuration, Danger, linters, scripts, and AI agent instructions such as this file.
    Classify improvements to internal engineering workflows as `type::maintenance`, following the handbook's [`maintenance::workflow` definition](https://handbook.gitlab.com/handbook/product/groups/product-analysis/engineering/metrics/#work-type-classification). Adding a tooling capability does not by itself make the change `type::feature`.
- `~security`, `~documentation`, and `~"Community contribution"` are not types. A subtype label is optional.
- Detail: the handbook [work type classification](https://handbook.gitlab.com/handbook/product/groups/product-analysis/engineering/metrics/#work-type-classification) is the SSOT. See also `.ai/principles/distilled/code-review.md` (Approval Requirements).
