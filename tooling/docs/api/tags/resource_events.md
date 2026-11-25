---
name: Resource events
external_docs: https://docs.gitlab.com/api/resource_label_events/
---
Use this API to retrieve the events that track changes to issues, merge requests, and epics:

- [Label](../../../../doc/user/project/labels.md) events record who added or removed a label, and when.
- [Iteration](../../../../doc/user/group/iterations/_index.md) events record iteration changes for issues.
- Milestone events record milestone changes for issues and merge requests.
- State events record state changes for issues, merge requests, and epics.
- Weight events record weight changes for issues.

State events do not track the initial state (`created` or `opened`) of a resource. For a resource
that was never closed or reopened, an empty list is returned.

> [!warning]
> The epic endpoints in this API are part of the Epics REST API, which was
> [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/460668) in GitLab 17.0 and is planned
> for removal in v5 of the API. From GitLab 17.4 to 18.0, if the new look for epics is enabled, or in
> GitLab 18.1 and later, use the Work Items API instead. This change is a breaking change.
