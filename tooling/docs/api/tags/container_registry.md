---
name: Container registry
external_docs: https://docs.gitlab.com/api/container_registry/
---
Use this API to manage the [GitLab container registry](../../../../doc/user/packages/container_registry/_index.md):
list the registry repositories in a project or a group, retrieve or delete individual repositories and
their tags, and receive registry events.

To authenticate with these endpoints from a CI/CD job, pass the [`$CI_JOB_TOKEN`](../../../../doc/ci/jobs/ci_job_token.md)
variable as the `JOB-TOKEN` header. The job token only has access to the container registry
of the project that created the pipeline.

When you delete tags in bulk with cURL, URL-encode any `+` character in a regular expression, for
example with `--data-urlencode`. Otherwise, the `+` is not processed correctly.

The container registry also has its own Docker Registry v2 endpoints, served by the registry and not
under `/api/v4`. They use a registry token, not a personal, project, or group access token. To get a
registry token, call `GET /jwt/auth?service=container_registry&scope=<scope>` on the GitLab instance.
The `scope` names the resource and the actions the token needs, for example
`repository:<project_path>:pull`, `push`, or `delete`. Pass the token to the registry in an
`Authorization: Bearer <token>` header.

- `DELETE /v2/<name>/manifests/<tag>` deletes an image tag by reference. A token requested with the
  `CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD` variables can delete tags only in the project that
  runs the job. The registry must have the `tag_delete` feature enabled. This endpoint was introduced
  in GitLab 16.4 and replaces the deprecated `DELETE /v2/<name>/tags/reference/<tag>` endpoint.
- `GET /v2/_catalog` lists all container repositories on the instance. It requires a token with the
  `registry:catalog:*` scope, which only administrators can get.
