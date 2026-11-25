---
name: DORA metrics
external_docs: https://docs.gitlab.com/api/dora/metrics/
---
Use this API to retrieve [DORA metrics](../../../../doc/user/analytics/dora_metrics.md) for
groups and projects. Additional metrics are available through the
[GraphQL API](../../../../doc/api/graphql/reference/_index.md).

These endpoints require the Reporter, Developer, Maintainer, or Owner role.

The `value` field in the response depends on the `metric`:

- `deployment_frequency`: The total number of successful deployments during the time period.
- `change_failure_rate`: The number of incidents divided by the number of deployments during the
  time period. Available only for the production environment.
- `lead_time_for_changes`: The median number of seconds between the merge of a merge request and the
  deployment of its commits, for all merge requests deployed during the time period.
- `time_to_restore_service`: The median number of seconds an incident was open during the time
  period. Available only for the production environment.

For the `monthly` and `all` intervals, the API calculates the median of the daily median values. This
can introduce a slight inaccuracy in the returned data.
