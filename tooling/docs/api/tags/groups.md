---
name: Groups
external_docs: https://docs.gitlab.com/api/groups/
---
Use this API to view and manage [groups](../../../../doc/user/group/_index.md) and the resources they contain, including:

- Group settings, members, and security settings.
- [Group issues](../../../../doc/user/project/issues/_index.md) and issue statistics.
- [Markdown uploads](../../../../doc/security/user_file_uploads.md) referenced in epics or wiki pages.
- Bulk [reassignment of placeholder users](../../../../doc/user/import/mapping/reassignment.md#request-reassignment-by-using-a-csv-file) after an import.

Endpoint responses might vary based on the [permissions](../../../../doc/user/permissions.md)
of the authenticated user in the group. If a user isn't a member of a private group, requests to
that group return a `404 Not Found` status code.

Every call to the group security settings endpoints must be authenticated.

For project members, use the [project members API](../../../../doc/api/project_members.md).

Placeholder reassignment endpoints require the Owner role for the group. User contribution mapping is
not supported when you import projects to a personal namespace. In that case, all contributions are
assigned to the personal namespace owner and they cannot be reassigned.
