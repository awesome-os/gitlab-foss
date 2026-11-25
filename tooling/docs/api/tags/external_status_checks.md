---
name: External status checks
external_docs: https://docs.gitlab.com/api/status_checks/
---
Use this API to manage [external status checks](../../../../doc/user/project/merge_requests/status_checks.md).

When you retry a failed status check, a successful request returns `202 Accepted`. If the status
check is not failed, the request returns `422 Unprocessable Entity` with the message
`External status check must be failed`.
