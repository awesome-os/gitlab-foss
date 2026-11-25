---
name: CI runners
external_docs: https://docs.gitlab.com/api/runners/
---
> [!warning]
> Registering a runner with a registration token is
> [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/380872) and disabled by default in
> GitLab 17.0 and later.

Use this API to register a [runner](../../../../doc/ci/runners/_index.md) with an instance, verify its
authentication, reset its authentication token, and unregister it. GitLab Runner uses these endpoints
itself.

To create a runner, or to manage runners that already exist, use the Runners endpoints.

A runner uses two tokens:

- A registration token (legacy) registers the runner. You get it from GitLab.
- An authentication token authenticates the runner with GitLab. Registering a runner with a
  registration token returns its authentication token. You can also get one by creating a runner
  with `POST /user/runners`, or by resetting the runner's authentication token.

After you register a runner, add its authentication token to the runner's configuration file.
