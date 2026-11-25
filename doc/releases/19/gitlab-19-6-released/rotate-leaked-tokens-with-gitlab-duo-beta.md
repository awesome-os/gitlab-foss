---
title: Rotate leaked tokens with GitLab Duo (beta)
tier: [ Ultimate ]
offering: [ gitlab_com ]
stage: software_supply_chain_security
documentation_link: "../../../ci/secrets/secrets_manager/rotate-leaked-tokens/"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/636986
categories: [ Secrets Management ]
level: secondary
---

In previous versions of GitLab, you fixed a leaked personal access token by hand.
You revoked the token, created a new one, stored the new value, and updated the code.

Now you can rotate the token and fix the code from the vulnerability details page.
Select **AI actions** > **Fix with AI**, then **Rotate and fix**:

- GitLab revokes the leaked token and creates a new one with the same name and scopes.
- GitLab Secrets Manager stores the new value, which is never shown to you or sent to GitLab Duo.
- GitLab Duo opens a merge request that replaces the hardcoded token with a reference to the secret.

This feature works with GitLab personal access tokens, including fine-grained tokens.
[GitLab Secrets Manager](../../../ci/secrets/secrets_manager/_index.md) must be active for the project.
