---
name: Geo
external_docs: https://docs.gitlab.com/api/geo_nodes/
---
Use this API to manage [Geo sites](../../../../doc/administration/geo/_index.md). All of these
endpoints require administrator access.

> [!warning]
> The Geo Nodes endpoints were [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/369140) in
> GitLab 16.0 and are planned for removal in v5 of the API. Use the
> [Geo Sites API](../../../../doc/api/geo_sites.md) instead. This change is a breaking change.

In Geo node status responses, `health_status` is either `Healthy` or `Unhealthy`. `health` is empty,
`Healthy`, or contains the error message.
