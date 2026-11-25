---
name: Notification settings
external_docs: https://docs.gitlab.com/api/notification_settings/
---
Use this API to retrieve and update [notification settings](../../../../doc/user/profile/notifications.md)
globally for your account, or for an individual group or project, which overrides the global setting.

These notification levels are recognized:

- `disabled`: Turn off all notifications.
- `participating`: Receive notifications for threads you have participated in.
- `watch`: Receive notifications for most activity.
- `global`: Use your global notification settings.
- `mention`: Receive notifications when you are mentioned in a comment.
- `custom`: Receive notifications for selected events.

If you use the `custom` level, you can control specific email events. These events are recognized:

| Event                           | Description |
| ------------------------------- | ----------- |
| `approver`                      | A merge request you're eligible to approve is created. |
| `change_reviewer_merge_request` | A merge request's reviewer is changed. |
| `close_issue`                   | An issue is closed. |
| `close_merge_request`           | A merge request is closed. |
| `failed_pipeline`               | A pipeline fails. |
| `fixed_pipeline`                | A previously failed pipeline is fixed. |
| `issue_due`                     | An issue is due tomorrow. |
| `merge_merge_request`           | A merge request is merged. |
| `merge_when_pipeline_succeeds`  | A merge request is set to auto-merge. |
| `moved_project`                 | A project is moved. |
| `new_epic`                      | A new epic is created. Premium and Ultimate only. |
| `new_issue`                     | A new issue is created. |
| `new_merge_request`             | A new merge request is created. |
| `new_note`                      | Someone adds a comment. |
| `new_release`                   | A new release is published. |
| `push_to_merge_request`         | Someone pushes to a merge request. |
| `reassign_issue`                | An issue is reassigned. |
| `reassign_merge_request`        | A merge request is reassigned. |
| `reopen_issue`                  | An issue is reopened. |
| `reopen_merge_request`          | A merge request is reopened. |
| `success_pipeline`              | A pipeline completes successfully. |
