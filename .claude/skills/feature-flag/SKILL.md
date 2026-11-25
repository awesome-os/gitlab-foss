---
name: feature-flag
description: Create a new feature flag YAML definition in gitlab-org/gitlab with `bin/feature-flag --non-interactive`, and prepare its rollout issue. Use when asked to add, introduce, or define a feature flag, or when code references a flag that has no definition in `config/feature_flags/` or `ee/config/feature_flags/`.
version: 1.0.0
---

# Create a feature flag definition

Always generate definitions with `bin/feature-flag`. Do not write the YAML by hand.
The script reads the flag types, group labels, rollout issue template, and milestone from their canonical sources,
so this skill does not repeat them.

Run `bin/feature-flag` without `--non-interactive` only if the user asks for it. The interactive mode blocks on prompts.

## 1. Gather the inputs

| Option | Required | Source |
|--------|----------|--------|
| `<name>` (positional) | Yes | Follow [naming new flags](../../../doc/development/feature_flags/_index.md#naming-new-flags). |
| `--type` | Yes | Choose with [feature flag types](../../../doc/development/feature_flags/_index.md#types-of-feature-flags). If the choice is unclear, ask the user. The `--help` output also lists deprecated types. The error for a missing `--type` lists only the valid ones. |
| `--group` | Yes | The `group::*` label on the related issue (`glab issue view <id> --output json --jq '.labels'`) or MR (`glab mr view <id> --output json --jq '.labels'`). If none, ask the user. |
| `--description` | Yes | One short sentence about what the flag gates. The script doesn't enforce it, but the YAML file and the rollout issue title use it. |
| `--feature-issue-url` | No | The issue the flag implements. |
| `--introduced-by-url` | No | The MR that adds the flag. Skip it if the MR doesn't exist yet. Danger suggests it later. |
| `--username` | No | GitLab username of the flag DRI. Ask the user. Don't guess. |
| `--ee` | No | Pass it when the flag is only used in EE code. |
| `--rollout-issue-url` | No | Pass it only if the rollout issue already exists. |

Use full URLs, never short references.

## 2. Create the definition

Run from the repository root, on a feature branch (the script refuses to run on `master`):

```shell
bin/feature-flag <name> --non-interactive \
  --type <type> \
  --group "<group label>" \
  --description "<description>" \
  [--feature-issue-url <url>] [--introduced-by-url <url>] [--username <username>] [--ee]
```

- To preview without writing files, add `--dry-run`.
- If the script fails with `Provide a valid --type` or `Provide a valid --group`, choose from the list in the error. Don't retry with guesses.
- If the flag already exists, the script stops. Pass `--force` only when the user wants to overwrite the definition.

The script prints the path of the new YAML file under `config/feature_flags/<type>/` or `ee/config/feature_flags/<type>/`.

## 3. Rollout issue

If the type needs a rollout issue and you didn't pass `--rollout-issue-url`, the script:

- Writes the filled-in rollout issue description to `tmp/feature_flags/<name>_rollout_issue.md` (`--rollout-issue-file <path>` overrides the path).
- Prints a suggested issue title.
- Leaves `rollout_issue_url` empty in the YAML file.

Creating the rollout issue is a separate decision. The flag can merge before the rollout issue exists.
Create the issue only when the user asks, and only once.
Before you create it, replace or remove any `<...>` placeholders left in the file.
For example, `/relate <feature-issue-link>` remains when you didn't pass `--feature-issue-url`.

```shell
glab issue create --repo gitlab-org/gitlab --yes \
  --title "<suggested title printed by the script>" \
  --description-file tmp/feature_flags/<name>_rollout_issue.md
```

Then set `rollout_issue_url` in the YAML file to the URL of the new issue.
For `glab` usage, load the `glab` skill.

## 4. Files to keep in mind

- The YAML definition belongs with the code that uses the flag.
- The rollout issue description file is temporary. Never stage or commit it. `tmp/` is ignored by Git, so it stays out unless someone force-adds it.
