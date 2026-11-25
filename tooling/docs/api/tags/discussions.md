---
name: Discussions
external_docs: https://docs.gitlab.com/api/discussions/
---
Use this API to manage [discussions](../../../../doc/user/discussions/_index.md). This includes
[comments, threads](../../../../doc/user/discussions/_index.md), and system notes about changes to an object
(for example, when a milestone changes).

To manage label notes, use the [resource label events API](../../../../doc/api/resource_label_events.md).

> [!warning]
> The epic discussion endpoints are part of the Epics REST API, which was
> [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/460668) in GitLab 17.0 and is planned
> for removal in v5 of the API. From GitLab 17.4 to 18.0, if the new look for epics is enabled, or in
> GitLab 18.1 and later, use the Work Items API instead. This change is a breaking change.

The API uses these note types:

- Note: a comment on the root of an issue, merge request, commit, or snippet.
- Discussion: a collection of discussion notes, often called a thread, in an issue, merge request,
  commit, or snippet.
- Discussion note: an individual item in a discussion.

GitLab might change a note body before it saves it. For example, it runs and then removes
quick actions.

To create a thread on a merge request diff:

1. Get the latest merge request diff version. The latest version is listed first in the versions
   response.
1. Use its `base_commit_sha`, `head_commit_sha`, and `start_commit_sha` as `position[base_sha]`,
   `position[head_sha]`, and `position[start_sha]`.
1. Set `position[position_type]` to `text`.
1. Set both `position[old_path]` and `position[new_path]` to the file path before and after the change.
1. Set the line:
   - For an added line, use `position[new_line]` and do not include `position[old_line]`.
   - For a removed line, use `position[old_line]` and do not include `position[new_line]`.
   - For an unchanged line, include both `position[new_line]` and `position[old_line]`. They might
     differ if earlier changes in the file changed the line number.

Incorrect `base_sha`, `head_sha`, or `start_sha` values can trigger the bug described in
[issue 296829](https://gitlab.com/gitlab-org/gitlab/-/issues/296829).

A line code has the form `<SHA>_<old>_<new>`, like `adc83b19e793491b1c6ea0fd8b46cd9f32e292fc_5_5`:

- `<SHA>` is the SHA1 hash of the filename.
- `<old>` is the line number before the change.
- `<new>` is the line number after the change.
