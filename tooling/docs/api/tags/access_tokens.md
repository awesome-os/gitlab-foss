---
name: Access tokens
external_docs: https://docs.gitlab.com/api/personal_access_tokens/
---
Use this API to interact with access tokens including:

- [Personal access tokens](../../../../doc/user/profile/personal_access_tokens.md).
- [Group access tokens](../../../../doc/user/group/settings/group_access_tokens.md).
- [Project access tokens](../../../../doc/user/project/settings/project_access_tokens.md).
- [Impersonation tokens](../../../../doc/api/rest/authentication.md#impersonation-tokens).

To self-rotate a group or project access token, authenticate with that token and use the `self`
keyword in the request URL, for example `POST /projects/:id/access_tokens/self/rotate`. The token
must have the `api` or `self_rotate` scope.

When you rotate a token, GitLab links the new token to the previous one. These connected tokens form
a token family. If a rotation request authenticates with a token that was already revoked, all active
tokens in the same token family are revoked.
