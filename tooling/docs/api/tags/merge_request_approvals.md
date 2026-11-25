---
name: Merge request approvals
external_docs: https://docs.gitlab.com/api/merge_request_approvals/
---
Use this API to manage [merge request approvals](../../../../doc/user/project/merge_requests/approvals/_index.md)
and the group and project [approval settings](../../../../doc/user/project/merge_requests/approvals/settings.md)
that govern them. All endpoints require authentication.

Endpoints to approve, unapprove, reset approvals, and retrieve approval state are available on all
tiers, including Free. All other endpoints require Premium or Ultimate, and each one shows its tier.

Group approval settings endpoints require the Owner role for the group. Project approval settings
endpoints require the Maintainer or Owner role for the project.

A project, group, or instance setting, or a merge request approval policy, can
[prevent editing approval rules in merge requests](../../../../doc/user/project/merge_requests/approvals/settings.md#prevent-editing-approval-rules-in-merge-requests).
When editing is prevented, open merge requests use the project approval rules instead of `regular`
and `any_approver` rules defined on the merge request. Rules of type `code_owner` and
`report_approver` on the merge request still apply. To get the rules that apply, use
`GET /projects/:id/merge_requests/:merge_request_iid/approval_state`. Requests to list or retrieve
the approval rules of a merge request return only rules stored on the merge request, such as
`code_owner` rules. Requests to create, update, or delete an approval rule for the merge request
return `403 Forbidden`.

> [!note]
> The `merge_request_iid` and `id` path parameters must each be a single value.
> Passing multiple space-separated values (for example, `451 454 458`) is not
> supported and returns `400 Bad Request`. To act on multiple merge requests,
> make one request per merge request IID.
