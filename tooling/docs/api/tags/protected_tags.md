---
name: Protected tags
external_docs: https://docs.gitlab.com/api/protected_tags/
---
Use this API to manage [protected tags](../../../../doc/user/project/protected_tags.md).

These access levels are recognized: `0` (No access), `30` (Developer role), `40` (Maintainer role),
and `60` (administrator). `60` is not available on GitLab.com.

Elements in the `allowed_to_create` array take the form `{user_id: integer}`, `{group_id: integer}`,
`{deploy_key_id: integer}`, or `{access_level: integer}`. `user_id`, `group_id`, and `access_level`
are available only on GitLab Premium and Ultimate. Each user must be a member of the project, and
the project must be shared with each group with at least the Developer role.
