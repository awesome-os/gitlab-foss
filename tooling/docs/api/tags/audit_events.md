---
name: Audit events
external_docs: https://docs.gitlab.com/api/audit_events/
---
Use this API to list and retrieve the
[audit events](../../../../doc/user/compliance/audit_events.md) recorded for an instance or a group.

> [!warning]
> Offset-based pagination for the audit event list endpoints was
> [deprecated](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/186194) in GitLab 17.8 and is
> planned for removal in GitLab 20.0. Use keyset-based pagination instead. This change is a breaking change.

Instance audit event endpoints require administrator access. Group audit event endpoints return the
audit events of all users to users with the Owner role, and only the events of their own actions to
users with the Developer or Maintainer role.

Requests to these endpoints are subject to configurable rate limits: per user for instance audit
events, and per user and group for group audit events.
