---
name: Attestations
external_docs: https://docs.gitlab.com/api/attestations/
---
Use this API to retrieve and download [provenance attestations](../../../../doc/ci/pipeline_security/slsa/level_3/provenance_v1.md) for a project.

Some endpoints return [Sigstore bundles](https://docs.sigstore.dev/about/bundle/) in the response.
For attestations that use the `SIGSTORE` attestation method, you can verify these bundles with the
GitLab CLI (`glab`) or `cosign`.

> [!note]
> The availability of these endpoints is controlled by a feature flag. They are available for
> testing, but not ready for production use.
