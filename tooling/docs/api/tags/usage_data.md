---
name: Usage data
external_docs: https://docs.gitlab.com/api/usage_data/
---
Use this API to track internal events and to retrieve the
[Service Ping](../../../../doc/development/internal_analytics/service_ping/_index.md) payload that
GitLab collects, including its non-SQL metrics and the queries behind it.

The Service Ping payload includes `schema_inconsistencies_metric`. Database schema inconsistencies are
expected, and are unlikely to indicate a problem with your instance. This metric is only for
troubleshooting ongoing issues, and should not be used as a regular health check. Interpret it only with
the guidance of GitLab Support. The metric reports the same database schema inconsistencies as the
database schema checker Rake task.
