---
name: Validity checks
---
Use this API to check whether raw token values are still active.

> [!note]
> The availability of this feature is controlled by a feature flag.
> While the feature flag is disabled, requests return `404 Not Found`.
> This feature is available for testing, but not ready for production use.

## History

- Endpoint to verify raw tokens introduced in GitLab 19.7
  [with a feature flag](../../../../doc/administration/feature_flags/_index.md) named `validity_checks_raw_token_api`.
  Disabled by default.
