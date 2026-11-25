---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/marketing/product-and-technical-marketing/technical-writing/#assignments>
description: Protect the stability and security of your instance with rate limits on requests to GitLab.
title: Rate limits
---

{{< details >}}

- Tier: Free, Premium, Ultimate
- Offering: GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> [!note]
> For GitLab.com, see
> [GitLab.com-specific rate limits](../user/gitlab_com/rate_limits.md#current-rate-limits).
>
> For GitLab Dedicated, see
> [Authenticated user rate limits](../administration/dedicated/user_rate_limits.md).

Rate limiting is a common technique used to improve the security and durability
of a web application.

For example, a simple script can make thousands of web requests every second. The requests could be:

- Malicious.
- Apathetic.
- Just a bug.

Your application and infrastructure may not be able to cope with the load. For more details, see
[Denial-of-service attack](https://en.wikipedia.org/wiki/Denial-of-service_attack).
Most cases can be mitigated by limiting the rate of requests from a single IP address.

Most [brute-force attacks](https://en.wikipedia.org/wiki/Brute-force_attack) are
similarly mitigated by a rate limit.

> [!note]
> General API rate limits exclude requests with a valid cross-site request forgery (CSRF) token from
> a browser session.
> With the LabKit rate limiter, these requests count as web traffic unless a specialized API limit applies.

To find which request limits apply together and which take precedence, see
[request rate limit precedence](precedence.md).

## Configuration options

You can set most rate limits in the **Admin** area. Some are available only through the API
or the Rails console, and you set the GitLab Pages rate limits in a configuration file.

### Admin area

You can set these rate limits in the **Admin** area of your instance:

- [API rate limits](api/_index.md)
- [Content creation rate limits](content_creation.md)
- [Git operations rate limits](git.md)
- [GitLab Orbit rate limits](../integration/orbit.md#configure-orbit-rate-limits)
- [Import and export rate limits](../administration/settings/import_export_rate_limits.md)
- [Incident management rate limits](../administration/settings/incident_management_rate_limits.md)
- [Pages domain rate limits](../administration/settings/pages_domain_rate_limits.md)
- [Pipeline creation rate limits](../administration/cicd/limits.md#pipeline-creation-rate-limits)
- [Protected paths](../administration/settings/protected_paths.md)
- [Raw endpoints rate limits](../administration/settings/rate_limits_on_raw_endpoints.md)
- [User and IP rate limits](../administration/settings/user_and_ip_rate_limits.md)
- [Webhook operations rate limits](../administration/settings/rate-limit-on-webhook-operations.md)

### API and Rails console

You can set these rate limits with the [application settings API](../api/settings.md):

- [Autocomplete users rate limit](../administration/instance_limits.md#autocomplete-users-rate-limit)
- [AI action](../api/settings.md#available-settings) (`ai_action_api_rate_limit`): 160 calls every
  8 hours for each authenticated user. Applies to the GraphQL `aiAction` mutation.
- [Create tag rate limit](../api/settings.md#available-settings) (`tags_create_limit`): 100 requests
  every 30 minutes for each project. Applies to the REST API endpoint for creating a tag, the
  GraphQL `tagCreate` mutation, tag creation in the UI, and the `/tag` quick action.
- [CSV import rate limit](../api/settings.md#available-settings) (`issuable_csv_import_limit`):
  20 imports every hour for each authenticated user. Applies to importing issues, work items, and
  requirements from CSV, in the UI and through the `workItemsCsvImport` GraphQL mutation. The limit
  is shared between them. Introduced in GitLab 19.6 [with a flag](../administration/feature_flags/_index.md)
  named `issuable_csv_import_rate_limit`. Disabled by default. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Work item move and clone rate limit](../api/settings.md#available-settings) (`work_item_move_limit`):
  100 requests every minute for each authenticated user. Applies to moving and cloning issues and work
  items in the UI, through the REST API endpoints for [moving an issue](../api/issues.md#move-an-issue)
  and [cloning an issue](../api/issues.md#clone-an-issue), through the `issueMove` and `workItemBulkMove`
  GraphQL mutations, through the `/move` and `/clone` quick actions, and through the Slack `issue move`
  command. The limit is shared between them. A bulk move counts as one request for each item,
  and a bulk move with more items than the limit is rejected.
  The child items moved with an issue also count as one request each.
  Moves and clones of a single issue that fail for other reasons also count.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268181) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named `work_item_move_rate_limit_enforce`.
  Disabled by default. While the flag is disabled, requests over the limit are logged but not blocked.
  This setting is in [beta](../policy/development_stages_support.md#beta) and might
  be changed or removed without notice.
- [Add child items rate limit](../api/settings.md#available-settings) (`work_item_hierarchy_add_children_limit`):
  300 child items every minute for each authenticated user. Applies to adding child items from the
  parent work item or epic: the `workItemHierarchyAddChildrenItems` GraphQL mutation, `childrenIds`
  in the `workItemUpdate` GraphQL mutation, the `/add_child` quick action, and the REST API endpoints
  for [assigning an issue to an epic](../api/epic_issues.md#assign-an-issue-to-an-epic) and
  [assigning a child epic](../api/epic_links.md#assign-a-child-epic). The limit is shared between them.
  Each child item in a request counts toward the limit, and if a request would exceed the limit, no
  child items are added. Does not apply when you set a parent from the child work item.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/266141) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `work_item_hierarchy_add_children_limits`. Disabled by default. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
  While the feature flag is disabled, requests over the limit are logged but not blocked.
- [Delete label rate limit](../api/settings.md#available-settings) (`label_delete_limit`):
  500 requests every minute for each authenticated user. Applies to deleting project and group
  labels in the UI and to the REST API endpoints for [deleting a project label](../api/labels.md#delete-a-project-label)
  and [deleting a group label](../api/group_labels.md#delete-a-group-label). The limit is shared between them.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267374) in GitLab 19.6 [with a feature flag](../administration/feature_flags/_index.md)
  named `label_delete_rate_limit`. Disabled by default. While the flag is disabled, deletes over the
  limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Merge request update rate limit](../api/settings.md#available-settings) (`merge_requests_update_limit`):
  600 updates every minute for each authenticated user. Applies to
  [updating a merge request](../api/merge_requests.md#update-a-merge-request) with the REST API,
  the GraphQL mutations that update merge requests, updating merge requests in the UI, and quick actions.
  The limit is shared between them.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/270214) in GitLab 19.7 [with a feature flag](../administration/feature_flags/_index.md)
  named `merge_requests_update_rate_limit`. Disabled by default. While the flag is disabled, updates over the
  limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Pages deployments query rate limit](../api/settings.md#available-settings)
  (`pages_deployments_api_limit`): 2,000 resolutions every minute for each authenticated user.
  Unauthenticated requests are limited to 2,000 resolutions every minute for each IP address. Applies to
  the GraphQL `pagesDeployments` field on `Project` and `Namespace`. Each resolution of the field counts
  once, so a query that returns deployments for 100 projects counts as 100. Introduced in GitLab 19.6
  [with a flag](../administration/feature_flags/_index.md) named `pages_deployments_api_rate_limit`.
  Disabled by default. While the flag is disabled, requests over the limit are logged but not blocked.
  This setting is in [beta](../policy/development_stages_support.md#beta)
  and might be changed or removed without notice.
- [Issue, epic, and work item update rate limit](../api/settings.md#available-settings) (`work_item_update_limit`):
  1,200 updates every minute for each authenticated user.
  Applies to updating issues, epics, and work items from their pages, boards, and quick actions in the UI,
  through the REST API endpoints for [updating an issue](../api/issues.md#update-an-issue),
  [reordering an issue](../api/issues.md#reorder-an-issue), [issue time tracking](../api/issues.md#time-tracking),
  [updating an epic](../api/epics.md#update-an-epic), and assigning an issue or a child epic to an epic,
  and through the GraphQL mutations that update them, including `updateIssue`, `workItemUpdate`, `updateEpic`,
  the `issueSet` mutations, and `issueMoveList`.
  The limit is shared between them.
  A bulk edit counts as one update for each item, and a bulk edit with more items than the limit is rejected.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268180) in GitLab 19.6 [with a feature flag](../administration/feature_flags/_index.md)
  named `work_item_update_rate_limit`. Disabled by default.
  While the `work_item_update_rate_limit` feature flag is disabled, updates over the limit are logged but not blocked.
  [Extended](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/271245) to issues closed by commits pushed to the default branch
  in GitLab 19.7 [with a feature flag](../administration/feature_flags/_index.md) named `rate_limit_issue_closing_from_commits`.
  Disabled by default.
  When `rate_limit_issue_closing_from_commits` is enabled, a commit pushed to the default branch counts as
  one update for each issue that the commit closes.
  Issues that are already closed are skipped and do not count.
  When `work_item_update_rate_limit` is enabled and the user who pushed the commit
  is over the limit, the commit closes no issues.
  This setting is in [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Epic board move rate limit](../api/settings.md#available-settings) (`epic_move_list_limit`):
  200 moves every minute for each authenticated user. Applies to the `epicMoveList` GraphQL
  mutation, and each alias in a request counts. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268609) in GitLab 19.6 [with a feature flag](../administration/feature_flags/_index.md)
  named `epic_move_list_rate_limit`. Disabled by default. While the flag is disabled, moves over
  the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Cross-reference rate limit](../api/settings.md#available-settings) (`cross_reference_checks_limit`):
  800 references every minute for each user. When you save a description or comment, GitLab adds
  a "mentioned in" note to each item it references.
  Each reference GitLab checks counts toward the limit. Commits do not count toward the limit.
  If the user is over the limit, the save succeeds, but GitLab adds no "mentioned in" notes for that save.
  Each save, including a pushed commit, checks at most 150 references.
  If a save has more references, GitLab checks work items and issues first, then merge requests,
  commits, and epics.
  [Internal users](../administration/internal_users.md) and service accounts with composite identity
  have a separate limit for each project or group. Project and group access token users have a
  single limit, like other users.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268220) in GitLab 19.6 [with a feature flag](../administration/feature_flags/_index.md)
  named `enforce_cross_reference_limits`. Disabled by default. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Milestone deletion rate limit](../api/settings.md#available-settings) (`milestone_destroy_limit`):
  10 requests every minute for each authenticated user. Applies to deleting a project or group
  milestone that has more than 10 issues and merge requests, in the UI and with the
  [project](../api/milestones.md#delete-a-milestone) and [group](../api/group_milestones.md#delete-group-milestone)
  milestones API. Deleting smaller milestones is not limited.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/266700) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named `milestone_destroy_rate_limit`. Disabled by default.
  While the flag is disabled, deletes over the limit are logged but not blocked.
  This setting is in [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Repository archive rate limit](../api/settings.md#available-settings)
  (`project_repositories_archive_limit`, `project_repositories_archive_unauthenticated_limit`):
  200 requests every minute for each authenticated user, across all projects.
  Unauthenticated requests are limited to 100 requests every minute for each IP address.
  Applies to [downloading repository archives](../api/repositories.md#retrieve-file-archive-from-a-repository)
  through the UI or the API.
  Requires the `archive_rate_limit` [feature flag](../administration/feature_flags/_index.md),
  which is disabled by default.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/270059) in GitLab 19.6
  [with a flag](../administration/feature_flags/_index.md) named `cross_project_archive_rate_limit`.
  Disabled by default.
  While the flag is disabled, requests over the limit are logged but not blocked.
  This setting is in [beta](../policy/development_stages_support.md#beta) and might be changed
  or removed without notice.
- [Retrieve file blame rate limit](api/repository-files.md#configure-file-blame-rate-limits)
  (`project_repositories_blame_limit`, `project_repositories_blame_unauthenticated_limit`):
  400 requests every minute for each user and project. Unauthenticated requests are limited
  to 400 requests every minute for each IP address. Applies to the REST API endpoint
  for file blame and to the GraphQL `blame` field on `RepositoryBlob`, which the blame view
  in the UI uses.
- [List repository commits rate limit](../api/settings.md#available-settings)
  (`project_repository_commits_api_limit`): 5,000 commits with stats every minute for each
  authenticated user, or for each IP address for unauthenticated requests. Applies to the REST API
  endpoint for [listing repository commits](../api/commits.md#list-repository-commits) when the
  `with_stats` or `all` parameter is used.
  A `with_stats` request counts as the number of commits returned,
  and a request that uses the `all` parameter counts as `3` more.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267664) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `rate_limit_project_repository_commits_api`. Disabled by default.
- [Compare repository refs rate limit](api/projects.md#configure-rate-limits-on-comparing-repository-refs)
  (`project_repositories_compare_limit`, `project_repositories_compare_unauthenticated_limit`):
  on GitLab.com, 5,000 requests every minute for each user, and 100 requests every minute for
  each IP address for unauthenticated requests. Off by default on GitLab Self-Managed and
  GitLab Dedicated. Applies to the REST API endpoint for
  [comparing branches, tags, or commits](../api/repositories.md#compare-branches-tags-or-commits).
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268459) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `compare_api_rate_limit`. Disabled by default. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Delete merged branches rate limit](api/projects.md#configure-rate-limits-on-deleting-merged-branches)
  (`delete_merged_branches_limit`): on GitLab.com, 60 requests every minute for each user.
  Off by default on GitLab Self-Managed and GitLab Dedicated. Applies to
  [deleting all merged branches](../api/branches.md#delete-all-merged-branches) through the API
  and the UI. The limit is shared between them.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269510) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `delete_merged_branches_rate_limit`. Disabled by default.
  Setting [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/272637) in GitLab 19.7.
- [List to-do items rate limit](../api/settings.md#available-settings) (`todos_list_api_limit`):
  300 requests every minute for each authenticated user. Applies to the REST API endpoint for
  [listing to-do items](../api/todos.md#list-all-to-do-items). [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/265469)
  in GitLab 19.6 [with a feature flag](../administration/feature_flags/_index.md) named
  `todos_list_api_rate_limit`. Disabled by default. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Protected branch write rate limit](../api/settings.md#available-settings) (`protected_branch_write_limit`):
  5,000 requests every hour for each user in each top-level group or personal namespace.
  Applies when a user protects or unprotects a branch in the UI, with the project or group REST API,
  or with the `branchRuleCreate` and `branchRuleDelete` GraphQL mutations.
  Protect and unprotect actions share the limit.
  Changes to an existing protected branch do not count against the limit.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267714) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `protected_branch_write_rate_limit_enforce`. Disabled by default. While the flag is disabled,
  GitLab counts requests over the limit but does not reject them. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without
  notice.
- [Markdown uploads rate limit](../api/settings.md#available-settings)
  (`markdown_upload_limit_megabytes_per_day`): 10,240 MB of uploaded files for each user in a
  24-hour window.
  The window starts with the user's first upload rather than at midnight.
  Unauthenticated uploads are limited for each IP address.
  Applies to files uploaded for use in Markdown in the UI, including for personal snippets and
  abuse reports.
  Also applies to the REST API for [projects](../api/project_markdown_uploads.md) and
  [groups](../api/group_markdown_uploads.md), and to the GraphQL `uploadCreate` mutation.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269433) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `markdown_uploads_rate_limit_enforce`. Disabled by default.
  [Enabled on GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/work_items/639259) in GitLab 19.6.
  While the flag is disabled, uploads over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Read wiki pages rate limit](../api/settings.md#available-settings)
  (`wiki_read_request_limit_unauthenticated`): 500 requests every minute for each project or group wiki,
  shared by all unauthenticated users. Applies to wiki pages in the UI and to the REST API endpoints
  that list and retrieve [project](../api/wikis.md) and [group](../api/group_wikis.md) wiki pages.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/266523) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `wiki_read_unauthenticated_rate_limit_enforce`. Disabled by default. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [GitLab Credits usage rate limit](../api/settings.md#available-settings)
  (`subscription_usage_per_minute_limit`, `subscription_usage_per_hour_limit`,
  `subscription_usage_per_day_limit`): 300 requests every minute, 10,000 every hour, and
  40,000 every day for each authenticated user. Applies to the GraphQL `subscriptionUsage`
  and `trialUsage` fields, which share one limit. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267552) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `enforce_subscription_usage_rate_limits`. Disabled by default. Available on GitLab.com only.
- [GitLab Credits budget cap rate limit](../api/settings.md#available-settings)
  (`budget_cap_update_per_minute_limit`, `budget_cap_update_per_hour_limit`,
  `budget_cap_update_per_day_limit`): 150 mutation calls every minute, 1,000 every hour, and
  20,000 every day for each authenticated user. Applies to the GraphQL
  `upsertUserBudgetCapOverrides` and `upsertFlatUserCap` mutations, which share one limit.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267593) in GitLab 19.6 [with a feature flag](../administration/feature_flags/_index.md)
  named `enforce_budget_cap_rate_limits`. Disabled by default. Available on GitLab.com only.
- [GitLab Credits user usage rate limit](../api/settings.md#available-settings)
  (`credits_usage_per_minute_limit`, `credits_usage_per_hour_limit`,
  `credits_usage_per_day_limit`): 60 requests every minute, 300 every hour, and
  3,000 every day for each authenticated user. Applies to the GraphQL `creditsUsage`
  field of `currentUser`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268363) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `enforce_credits_usage_rate_limits`. Disabled by default. Available on GitLab.com only.
- [Billable users rate limit](../api/settings.md#available-settings)
  (`billed_users_scan_per_minute_limit`, `billed_users_scan_per_hour_limit`,
  `billed_users_scan_per_day_limit`): 500 requests every minute, 2,500 every hour, and
  20,000 every day for each authenticated user in each top-level group. Applies to requests
  that calculate the billable users of a top-level group, which share one limit:
  - The REST API endpoint to [list all billable group members](../api/group_members.md#list-all-billable-group-members).
  - The GraphQL `billableMembersCount` field of `Group`.
  - [Seat usage data exports](../subscriptions/manage_seats.md#export-seat-usage-data).
  - The `GET /namespaces/:id/gitlab_subscription` REST API endpoint, only for groups on GitLab.com
    on the Free tier or a trial.

  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269334) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `enforce_billed_users_scan_rate_limits`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked.
- [Seat usage export rate limit](../api/settings.md#available-settings) (`seat_usage_export_limit`):
  10 exports every hour for each authenticated user in each top-level group. Applies to seat usage
  data exports, in addition to the billable users rate limit.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269383) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `enforce_billed_users_scan_rate_limits`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked.
- [Payment form rate limit](../api/settings.md#available-settings)
  (`subscriptions_payment_form_per_hour_limit`, `subscriptions_validate_payment_method_per_hour_limit`):
  20 payment form requests and 10 payment method validation requests every hour for each
  authenticated user, or for each IP address during identity verification.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269651) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `enforce_subscriptions_payment_form_rate_limits`. Disabled by default.
  Available on GitLab.com only.
- [Trial and hand-raise lead rate limits](../api/settings.md#available-settings)
  (`trial_create_limit`, `hand_raise_lead_create_limit`): 10 requests every hour for each
  authenticated user. Applies to creating a trial and to submitting a hand-raise lead on GitLab.com.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/work_items/635543) in GitLab 19.7.
- [Bulk add-on seat assignment rate limit](../api/settings.md#available-settings)
  (`user_add_on_assignment_bulk_create_limit`): disabled by default (`0`). When set to a value
  above `0`, counts calls every minute for each authenticated user. Applies to the
  `userAddOnAssignmentBulkCreate` GraphQL mutation.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/270545) in GitLab 19.7.
- [Rebase merge request rate limit](../api/settings.md#available-settings) (`merge_requests_rebase_limit`):
  30 requests every minute for each authenticated user. Applies to the REST API endpoint for
  [rebasing a merge request](../api/merge_requests.md#rebase-a-merge-request), rebasing from the UI,
  and the `/rebase` quick action. The limit is shared between them.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267972) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `merge_requests_rebase_rate_limit`. Disabled by default. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Merge request diff resources rate limit](../api/settings.md#available-settings)
  (`merge_request_diff_resources_request_limit`): 360 requests every minute for each
  authenticated user, or for each IP address for unauthenticated requests. Applies to
  `diffs_stream`, `diffs_stats`, and `diff_files_metadata`, which the **Changes** tab of a
  merge request loads. The three share one limit.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269240) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `merge_request_diff_resources_rate_limit`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Merge request changes rate limit](../api/settings.md#available-settings)
  (`merge_request_diffs_page_request_limit`): 120 requests every minute for each
  authenticated user, or for each IP address for unauthenticated requests. Applies to
  loading the **Changes** tab of a merge request in the UI.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268216) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `merge_request_diffs_page_rate_limit`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Compute usage projects rate limit](../api/settings.md#available-settings)
  (`ci_minutes_usage_projects_per_minute_limit`, `ci_minutes_usage_projects_per_hour_limit`):
  60 requests every minute and 600 every hour for each authenticated user. Applies to
  requests to the GraphQL `ciMinutesUsage` field that select the `projects` field.
  Requests over the limit return the monthly usage, but not the `projects` field.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269636) in GitLab 19.7 [with a feature flag](../administration/feature_flags/_index.md)
  named `enforce_ci_minutes_usage_rate_limits`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked.
  Available on GitLab.com only.
- [Merge request diff and patch download rate limit](../api/settings.md#available-settings)
  (`merge_request_diff_download_request_limit`): 120 requests every minute for each
  authenticated user, or for each IP address for unauthenticated requests. Applies to
  downloading a merge request as a `.diff` or `.patch` file, including a single version of a merge request.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/270001) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `merge_request_diff_download_rate_limit`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Merge request comment fetch rate limit](../api/settings.md#available-settings)
  (`merge_request_notes_index_unauthenticated_limit`): 60 unauthenticated requests every minute
  for each IP address. Applies to the
  endpoint that merge request pages call to fetch new and changed comments.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/272455) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `merge_request_notes_index_unauthenticated_rate_limit`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Merge request diff read rate limit](../api/settings.md#available-settings) (`merge_requests_read_diffs_limit`):
  300 requests every minute for each authenticated user, or for each IP address for unauthenticated
  requests. Applies to the REST API endpoints that retrieve merge request changes, diffs, raw diffs,
  and diff versions. The limit is shared between them, and each page of diffs counts as one request.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/work_items/606717) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `merge_requests_read_diffs_rate_limit_enforce`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Merge ref rate limit](../api/settings.md#available-settings) (`merge_requests_merge_ref_limit`):
  Disabled by default. When set, limits requests every minute for each user, or for each IP address
  for unauthenticated requests.
  Applies to the REST API endpoint to
  [merge to the default merge ref path](../api/merge_requests.md#merge-to-default-merge-ref-path).
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/270070) in GitLab 19.7.
- [DAST configuration page rate limit](../api/settings.md#available-settings) (`dast_configuration_show_limit`):
  Disabled by default. When set, limits views of the DAST configuration page every minute for each user.
  Applies only when the `dast_configuration_rate_limit` [feature flag](../administration/feature_flags/_index.md) is enabled.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/work_items/637251) in GitLab 19.7.
- [Scanned resources CSV download rate limit](../api/settings.md#available-settings) (`scanned_resources_csv_download_limit`):
  Disabled by default. When set, limits downloads of the scanned resources CSV for a pipeline every minute for each user.
  Applies only when the `scanned_resources_csv_limits` [feature flag](../administration/feature_flags/_index.md) is enabled.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/work_items/637250) in GitLab 19.7.
- [Scanned resources GraphQL rate limit](../api/settings.md#available-settings) (`scanned_resources_pipelines_query_limit`):
  Disabled by default. When set, limits the number of pipelines every minute, for each user, whose
  `scannedResources` or `scannedResourcesCount` GraphQL fields are requested.
  Applies only when the `scanned_resources_graphql_limits` [feature flag](../administration/feature_flags/_index.md) is enabled.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/work_items/637250) in GitLab 19.7.
- [Namespace visit tracking rate limit](../api/settings.md#available-settings)
  (`track_namespace_visits_limit`): 60 requests every minute for each authenticated user.
  Applies to the requests the left sidebar sends to record your group and project visits.
  GitLab uses these visits to suggest frequently visited groups and projects.
  When the limit is enforced, visits over the limit are not recorded.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/272280) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `enforce_track_namespace_visits_rate_limit`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.
- [Auto-remediation scheduler rate limit](../api/settings.md#available-settings)
  (`security_update_scheduler_project_period_in_seconds` in `dependency_management_settings`):
  1 run and 1 reschedule run for each project every 300 seconds. Applies to
  [dependency scanning auto-remediation](../user/application_security/remediate/dependency_scanning_auto_remediation.md)
  scheduler runs. GitLab skips a run over the limit and does not retry it. The next pipeline after
  the period starts a new run. Reschedule runs, which fill a slot freed by a dismissed update, have
  their own limit. Set to `0` to remove both limits. The maximum is `86400` seconds. A shorter period
  applies to a project after its current period ends.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267539) in GitLab 19.6
  [with a feature flag](../administration/feature_flags/_index.md) named
  `dependency_management_scheduler_rate_limit`. Disabled by default.
  [Generally available](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/272129) in GitLab 19.7.
  Feature flag `dependency_management_scheduler_rate_limit` removed.
  The period [became configurable](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/271226) in GitLab 19.7.
- [GraphQL participants rate limit](../api/settings.md#available-settings)
  (`graphql_participant_fields_request_limit`): 100 requests every minute for each
  authenticated user, or for each IP address for unauthenticated requests. Applies to GraphQL
  requests that resolve the `participants` and `subscribed` fields of issues, merge requests,
  epics, and work items more than 20 times in total, for example by listing more than 20 items
  with one of these fields. Batched queries in one request count together.
  Requests that resolve these fields 20 times or fewer don't count.
  Requests over the limit return `429 Too Many Requests`.
  [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/271502) in GitLab 19.7
  [with a feature flag](../administration/feature_flags/_index.md) named
  `graphql_participant_fields_rate_limit`. Disabled by default. While the flag is disabled,
  requests over the limit are logged but not blocked. This setting is in
  [beta](../policy/development_stages_support.md#beta) and might be changed or removed without notice.

You can set this rate limit with the [plan limits API](../api/plan_limits.md) or the
[Rails console](../administration/operations/rails_console.md#starting-a-rails-console-session):

- [Webhook rate limit](../administration/instance_limits.md#webhook-rate-limit)

### Configuration file

You can set these rate limits only in the configuration file for your installation, for example
`/etc/gitlab/gitlab.rb` in a Linux package installation:

- [GitLab Pages rate limits](../administration/pages/rate-limits.md)

## Non-configurable limits

Some rate limits cannot be configured.
For a list of these limits, see [non-configurable rate limits](non_configurable.md).

## Bans and blocks

Some protections block a client for a period of time instead of slowing requests down.
For more information, see [abuse and failed authentication bans](abuse_bans.md).

## Related topics

- [GitLab application limits](../administration/instance_limits.md)
- [CI/CD limits](../administration/cicd/limits.md)
