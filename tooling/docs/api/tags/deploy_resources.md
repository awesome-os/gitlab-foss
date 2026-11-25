---
name: Deploy resources
external_docs: https://docs.gitlab.com/api/deploy_keys/
---
Use this API to manage [deploy keys](../../../../doc/user/project/deploy_keys/_index.md),
[deploy tokens](../../../../doc/user/project/deploy_tokens/_index.md), and
[code deployments](../../../../doc/ci/environments/deployments.md) to GitLab environments.

Project deploy token endpoints require the Maintainer or Owner role for the project. Listing group
deploy tokens requires the Maintainer or Owner role for the group. Creating and deleting group deploy
tokens requires the Owner role for the group.

Some deploy key endpoints return public key fingerprints. You can use these fingerprints with the
keys API to identify the user that created the deploy key. These attributes contain the fingerprint:

- `fingerprint`: Uses an MD5 hash. Not available on FIPS-enabled systems.
- `fingerprint_sha256`: Uses a SHA256 hash. Returned without the `SHA256:` prefix. To look up a key
  by this fingerprint with the keys API, add the prefix.
