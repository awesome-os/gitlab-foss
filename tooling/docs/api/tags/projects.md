---
name: Projects
external_docs: https://docs.gitlab.com/api/projects/
---
Use this API to manage [projects](../../../../doc/user/project/_index.md) and the resources they contain, including:

- Project settings, visibility, access permissions, and security settings.
- Archiving, transferring, [forking](../../../../doc/user/project/repository/forking_workflow.md), and [starring](../../../../doc/user/project/working_with_projects.md) projects.
- Project [issues](../../../../doc/user/project/issues/_index.md), issue statistics, and project statistics.
- [Markdown uploads](../../../../doc/security/user_file_uploads.md) referenced in issues, merge requests, snippets, or wiki pages.
- Protection rules for [container image tags](../../../../doc/user/packages/container_registry/protected_container_tags.md), container repositories, and [packages](../../../../doc/user/packages/package_registry/package_protection_rules.md).

If a user is not a member of a private project, a `GET` request on that project results in a
`404` status code.

To read the properties of a private project, you need any default role on the project. To edit project
properties, you need the Maintainer or Owner role on each project you change.

A project has one of three visibility levels: `private`, `internal`, or `public`. The fields returned in
responses vary based on the permissions of the authenticated user.

Each project feature access level setting is defined independently and accepts these values:

- `disabled`: Turns off the feature.
- `private`: Turns on the feature for project members only.
- `enabled`: Turns on the feature for everyone with access to the project.
- `public`: Turns on the feature for everyone. Available only for `pages_access_level`.

If Pages access control is turned on, private projects accept `disabled`, `private`, and `public` for
`pages_access_level`, internal projects accept all four values, and public projects accept `disabled`,
`private`, and `enabled`. `public` is also rejected when public access to Pages is turned off for the
instance or the group.

New projects have Service Desk turned on by default. To turn off Service Desk for several projects, update
each project and set `service_desk_enabled` to `false`.

To remove a project avatar, update the project with a blank value for `avatar`.

The returned `restrict_user_defined_variables` value is derived from
`ci_pipeline_variables_minimum_override_role`, which takes priority when you set both. It is `false` only
when the minimum override role is `developer`. For example, setting `restrict_user_defined_variables` to
`true` and `ci_pipeline_variables_minimum_override_role` to `developer` returns
`restrict_user_defined_variables: false`. Setting `restrict_user_defined_variables` to `false` and
`ci_pipeline_variables_minimum_override_role` to `maintainer` returns `restrict_user_defined_variables: true`.

Every call to the project statistics and project security settings endpoints must be authenticated.
Project statistics count the number of times the project is cloned or pulled over HTTP. SSH fetches
are not included.
