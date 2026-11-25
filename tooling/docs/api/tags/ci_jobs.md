---
name: CI jobs
external_docs: https://docs.gitlab.com/api/jobs/
---
Use this API to interact with [CI/CD jobs](../../../../doc/ci/jobs/_index.md).

A job response includes `artifacts_file` while the artifacts archive is downloadable, even after
`artifacts_expire_at` has passed. Artifacts kept by the **Keep artifacts from most recent successful
jobs** setting do not expire.

The `status` field in job responses and the `scope` parameter for filtering jobs use these values:

- `canceled`: Job was manually canceled or automatically aborted.
- `canceling`: Job is being canceled but `after_script` is running.
- `created`: Job has been created but not yet processed.
- `failed`: Job execution failed.
- `manual`: Job requires manual action to start.
- `pending`: Job is in the queue waiting for a runner.
- `preparing`: Runner is preparing the execution environment.
- `running`: Job is executing on a runner.
- `scheduled`: Job has been scheduled but execution has not started.
- `skipped`: Job was skipped due to conditions or dependencies.
- `success`: Job completed successfully.
- `waiting_for_callback`: Job is waiting for a callback from an external service.
- `waiting_for_resource`: Job is waiting for resources to become available.
