---
name: Job artifacts
external_docs: https://docs.gitlab.com/api/job_artifacts/
---
Use this API to download, keep, and delete [job artifacts](../../../../doc/ci/jobs/job_artifacts.md).

Merge request pipelines run on `refs/merge-requests/:iid/head`, not on the source branch. To download
artifacts from a merge request pipeline by reference name, use `refs/merge-requests/:iid/head` as the
`ref_name`. In merge request pipelines, the merge request ID is available in the
`$CI_MERGE_REQUEST_IID` variable and the full `ref_name` in the `$CI_MERGE_REQUEST_REF_PATH` variable.

Report artifacts are not included in the artifacts archive by default. To download a report, set
`file_type` when you download job artifacts by job ID, or add the report filename or
`gl-*-report.json` to `artifacts:paths` so the report is included in the archive.
