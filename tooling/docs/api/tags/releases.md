---
name: Releases
external_docs: https://docs.gitlab.com/api/releases/
---
Use this API to manage [releases](../../../../doc/user/project/releases/_index.md) for a project,
list the releases across a group, and manage the asset links attached to a release.

Asset links support the `http`, `https`, and `ftp` protocols.

For authentication, the Releases API accepts either a personal access token in the `PRIVATE-TOKEN`
header, or the CI/CD job token `$CI_JOB_TOKEN` in the `JOB-TOKEN` header.

When you create or update a release, the `milestones` and `milestone_ids` parameters accept group
milestones only from the project's group. Specifying a milestone of an ancestor group returns an error.

In release responses, `upcoming_release` is `true` when `released_at` is set to a future date.
