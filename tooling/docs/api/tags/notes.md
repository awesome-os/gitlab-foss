---
name: Notes
external_docs: https://docs.gitlab.com/api/notes/
---
Use this API to manage the comments and system records attached to GitLab content. You can:

- Create and modify comments on issues, merge requests, epics, snippets, commits, and wiki pages.
- Retrieve [system-generated notes](../../../../doc/user/project/system_notes.md) about object changes.
- Control visibility with confidential and internal flags.

Note creation is rate limited for each user. Administrators set the number of `Create` requests
allowed each minute with the `notes_create_limit` application setting. Default is `300`.

When you create or update a note on an issue, merge request, epic, or commit, GitLab normalizes the
body before it saves it. This applies to notes sent through any API, including the Discussions,
Draft notes, and Commits APIs. GitLab:

- Runs and then removes any quick actions.
- Removes carriage return characters (`\r`).
- Removes trailing whitespace, including trailing newlines.

As a result, the `body` returned by later requests might not match the `body` you sent. Notes on
snippets and wiki pages are saved as sent.

> [!warning]
> The epic notes endpoints are part of the Epics REST API, which was
> [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/460668) in GitLab 17.0 and is planned
> for removal in v5 of the API. From GitLab 17.4 to 18.0, if the new look for epics is enabled, or in
> GitLab 18.1 and later, use the Work Items API instead. This change is a breaking change.

Some system-generated notes are tracked as separate resource events instead, including
[label](../../../../doc/api/resource_label_events.md),
[state](../../../../doc/api/resource_state_events.md),
[milestone](../../../../doc/api/resource_milestone_events.md),
[weight](../../../../doc/api/resource_weight_events.md), and
[iteration](../../../../doc/api/resource_iteration_events.md) events.

By default, `GET` requests return 20 results at a time, because the results are
[paginated](../../../../doc/api/rest/_index.md#pagination).
