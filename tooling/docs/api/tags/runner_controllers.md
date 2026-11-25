---
name: Runner controllers
external_docs: https://docs.gitlab.com/api/runner_controllers/
---
Use this API to manage the runner controllers that handle CI/CD job admission control, and the scopes
assigned to them. Runner controllers connect to the job router and evaluate jobs against custom
policies, deciding whether to admit or reject them.

Runner controller scopes define which jobs a runner controller evaluates for admission control. A
runner controller must have at least one scope to receive admission requests. Without a scope, the
controller remains inactive even when its state is `enabled` or `dry_run`.

These endpoints require administrator access to the instance.

> [!note]
> The availability of these endpoints is controlled by a feature flag. They are available for
> testing, but not ready for production use.
