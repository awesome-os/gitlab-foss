---
name: Project mirrors
external_docs: https://docs.gitlab.com/api/project_pull_mirroring/
---
Use this API to manage project [pull mirroring](../../../../doc/user/project/repository/mirror/pull.md).

> [!warning]
> Configuring pull mirroring with the `mirror` and `import_url` attributes of the projects API was
> deprecated in GitLab 17.6 and is planned for removal in v5 of the API. Use the endpoint that
> updates project pull mirroring settings instead. This change is a breaking change.

With the deprecated method, if the remote repository is publicly accessible or uses
`username:token` authentication, configure pull mirroring when you create or update a project.
To enable pull mirroring, set `mirror` to `true` and set `import_url` to the URL of the remote
repository. To disable it, set `mirror` to `false`. If your HTTP repository is not publicly
accessible, add the authentication information to the URL, for example
`https://username:token@gitlab.company.com/group/project.git`, where `token` is a personal access
token with the `api` scope enabled.
