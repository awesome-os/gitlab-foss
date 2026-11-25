---
name: Experiments
external_docs: https://docs.gitlab.com/api/experiments/
---
Use this API to retrieve the A/B experiments running on an instance. This API is for internal use
only, requires you to be a [GitLab team member](https://gitlab.com/groups/gitlab-com/-/group_members),
and cannot be used with anonymous or unauthenticated users. For experiments involving anonymous users,
use the [`glex_force` query parameter](../../../../doc/development/experiment_guide/implementing_experiments.md#client-side-glex_force-query-parameter)
instead.

Use the experiment assignment endpoints to force, read, and clear experiment variant assignments in
the GLEX Redis cache. This is useful for backend-only experiments that run outside of a
request/response cycle, where the `glex_force` query parameter is not available. The experiment must
declare `context_keys` in its experiment class in `app/experiments`.
