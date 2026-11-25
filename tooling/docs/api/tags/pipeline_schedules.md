---
name: Pipeline schedules
external_docs: https://docs.gitlab.com/api/pipeline_schedules/
---
Use this API to interact with [pipeline schedules](../../../../doc/ci/pipelines/schedules.md).

The API cannot automatically expand a short `ref` to a full `ref` when:

- Both a branch and a tag exist with the same name as the short `ref`.
- No branch or tag exists with that name.

To resolve this issue, provide the full `ref`, for example `refs/heads/main` or `refs/tags/main`.
