---
name: Approval rules
external_docs: https://docs.gitlab.com/api/merge_request_approvals/
---
Use this API to manage the [merge request approval rules](../../../../doc/user/project/merge_requests/approvals/rules.md)
defined for a project or a group, where the rules of a group apply to the projects it contains.

All endpoints require authentication. To manage the approval rules of an individual merge request,
use the [merge request approvals API](../../../../doc/api/merge_request_approvals.md).

Group approval rules apply to all protected branches of projects in the group. The group approval
rules endpoints are behind a feature flag named `approval_group_rules`, disabled by default.
