---
name: Merge requests
external_docs: https://docs.gitlab.com/api/merge_requests/
---
Use this API to manage [merge requests](../../../../doc/user/project/merge_requests/_index.md) in a
project, and to list the merge requests across a group or an entire instance. You can:

- Automate any part of the code review process.
- Connect code changes to external tools.
- Send merge request information to non-GitLab systems in your preferred format.
- Update, approve, merge, or block merge requests based on data from external systems.
- Add [commits from previous merge requests](../../../../doc/user/project/merge_requests/commits.md#show-commits-from-previous-merge-requests) to a merge request for more context.

All API calls to non-public information require authentication.

The `approvals_before_merge` attribute is deprecated and is scheduled for removal in API v5. Use the
merge request approvals API instead.

The mergeability (`merge_status`) of a merge request is checked asynchronously when you retrieve the
merge request. Poll the endpoint to get the updated status. The `has_conflicts` attribute depends on
`merge_status`, and is `false` unless `merge_status` is `cannot_be_merged`. Use
`detailed_merge_status` instead of `merge_status` to account for all potential statuses.

Listing merge requests might not update `merge_status` and `has_conflicts`, because the check is
expensive. To get current values from a list endpoint, set `with_merge_status_recheck` to `true`.

When you create a merge request, the `diff_refs` and `changes_count` attributes are empty. They
populate asynchronously after the merge request is created.
