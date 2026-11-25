---
name: Group credentials inventory
external_docs: https://docs.gitlab.com/api/groups/
---
Use this API to manage the credentials that members of a top-level group hold, including their
personal access tokens, resource access tokens, and SSH keys. You can list these credentials, revoke
them, and rotate the tokens. For more information, see
[credentials inventory](../../../../doc/administration/credentials_inventory.md).

These endpoints are available on GitLab.com only. They cover the credentials of enterprise users and
service accounts, and the group and project access tokens in the group. You must be an administrator
or have the Owner role for the group.
