---
name: Service accounts
external_docs: https://docs.gitlab.com/api/service_accounts/
---
Use this API to interact with [service accounts](../../../../doc/user/profile/service_accounts.md).

The number of service accounts you can create depends on your subscription and offering:

- On GitLab Premium and Ultimate, you can create an unlimited number of service accounts for all offerings.
- On GitLab Free, limits vary by offering:
  - For GitLab.com, you can create up to 100 service accounts for each top-level group.
    This includes service accounts created in subgroups or projects.
  - For GitLab Self-Managed, you can create up to 100 service accounts for the entire instance.
    This includes service accounts created for the instance, a group, or a project.

You can also interact with service accounts through the [users API](../../../../doc/api/users.md).
To manage SSH keys for service accounts, use the [user SSH and GPG keys API](../../../../doc/api/user_keys.md).

Instance service accounts are available to an entire GitLab instance, but must still be added to
groups and projects like a human user. Managing instance service accounts requires administrator
access to the instance.

Group service accounts are owned by a specific group. A service account created in a top-level group
can be invited to any group or project on the instance. A service account created in a subgroup can
be invited only to that subgroup and its descendant subgroups or projects. To manage group service
accounts:

- On GitLab.com, you must have the Owner role for the group.
- On GitLab Self-Managed or GitLab Dedicated, you must either be an administrator for the instance,
  or have the Owner role in a group and be allowed to create service accounts.

Project service accounts are owned by a specific project and are available only to their
associated project. To manage project service accounts:

- On GitLab.com, you must have the Maintainer or Owner role for the project.
- On GitLab Self-Managed or GitLab Dedicated, you must either be an administrator for the instance,
  or have the Maintainer or Owner role in the project.
