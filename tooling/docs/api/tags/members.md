---
name: Members
external_docs: https://docs.gitlab.com/api/group_members/
---
Use this API to manage the [members](../../../../doc/user/project/members/_index.md) of a group or a
project, including inherited memberships, membership approvals, and the billable members of a group.

Some member attributes are visible only to some users:

- The `group_saml_identity` and `group_scim_identity` attributes are visible only to group owners
  for SSO-enabled groups.
- The `email` attribute is visible only to group owners for enterprise users of the group, when the
  request is sent to the group itself, or to that group's subgroups or projects.
- The `two_factor_enabled` attribute is visible only to group owners and administrators.
