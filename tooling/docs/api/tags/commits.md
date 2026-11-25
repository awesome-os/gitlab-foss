---
name: Commits
external_docs: https://docs.gitlab.com/api/commits/
---
Use this API to manage [Git commits](../../../../doc/user/project/repository/commits/_index.md).

The `created_at` field exists for consistency with other GitLab APIs, and is always identical to
the `committed_date` field. The `committed_date` and `authored_date` fields come from different
sources, and might not be identical.

For performance reasons, the endpoints that list repository commits and the references a commit is
pushed to do not return the `x-total` and `x-total-pages` pagination headers.
