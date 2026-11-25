---
name: Protected branches
external_docs: https://docs.gitlab.com/api/protected_branches/
---
Use this API to manage [protected branches](../../../../doc/user/project/repository/branches/protected.md)
for a project, and the [protected branch settings](../../../../doc/user/project/repository/branches/protected.md#in-a-group)
that all projects in a group inherit.

GitLab Premium and GitLab Ultimate support more granular protections for pushing to branches.
Administrators can grant permission to modify and push to protected branches only to deploy keys,
instead of specific users.

> [!warning]
> Group protected branch settings are restricted to top-level groups. They support only
> [valid access levels](../../../../doc/api/group_protected_branches.md#valid-access-levels)
> and, on GitLab Ultimate, custom roles (`member_role_id`). They cannot name individual users or groups.
> The custom role must belong to the same top-level group as the protected branch.

Valid access levels are:

- `0`: No access. Valid for push and merge access levels only, not for unprotect access levels.
- `30`: Developer.
- `40`: Maintainer.
- `60`: Administrator. Valid for GitLab Self-Managed only.

On project protected branches, you can also assign access by:

- User (`user_id`): Valid for push, merge, and unprotect access levels. The user must have access to
  the project.
- Group (`group_id`): Valid for push, merge, and unprotect access levels. The group must have the
  project shared with it, with the Developer, Maintainer, or Owner role.
- Deploy key (`deploy_key_id`): Valid for push access levels only. The deploy key must be enabled
  for the project and have write access to the project repository.

Each element in the `allowed_to_push`, `allowed_to_merge`, and `allowed_to_unprotect` arrays takes
the form `{user_id: integer}`, `{group_id: integer}`, `{deploy_key_id: integer}`,
`{member_role_id: integer}`, or `{access_level: integer}`. `user_id`, `group_id`, and `access_level`
are available only on GitLab Premium and Ultimate. `member_role_id` is available only on GitLab
Ultimate. `deploy_key_id` is valid only in `allowed_to_push`.

On GitLab Premium and Ultimate, to update a project protected branch, you must be included in its `allowed_to_unprotect` configuration.
To modify an existing access level record, include its `id`. To remove an access level, include its
`id` and set `_destroy` to `true`.

> [!note]
> To avoid permanently locking protection settings for a branch, ensure at least one user or group
> retains unprotect permissions for the branch at all times.
