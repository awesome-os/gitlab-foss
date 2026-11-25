---
name: Hooks
external_docs: https://docs.gitlab.com/api/group_webhooks/
---
Use this API to manage the hooks that GitLab uses to notify external services about events:

- [Project webhooks](../../../../doc/user/project/integrations/webhooks.md) are limited to a single project.
- [Group webhooks](../../../../doc/user/project/integrations/webhooks.md#group-webhooks) apply to all projects and subgroups in a group.
- [System hooks](../../../../doc/administration/system_hooks.md) apply to the entire instance.

You can also test a hook, inspect its event log, resend an event, and manage its custom headers and
URL variables.

Managing project webhooks requires administrator access or the Maintainer or Owner role for the
project. Managing group webhooks requires administrator access or the Owner role for the group.
Managing system hooks requires administrator access.

Each system hook belongs to one organization, and the `organization_id` attribute shows which one.
System hook endpoints work only with the hooks of the current organization:

- Lists return only hooks in the current organization.
- New hooks are created in the current organization.
- Requests for a hook in another organization return `404 Not Found`. These requests include
  retrieving, updating, deleting, and testing the hook and managing its URL variables and custom
  headers.
