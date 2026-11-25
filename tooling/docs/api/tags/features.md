---
name: Features
external_docs: https://docs.gitlab.com/api/features/
---
Use this API to manage the Flipper-based feature flags used in the development of GitLab itself.

These endpoints support boolean, percentage-of-time, and percentage-of-actors gate values, and require
administrator authorization.

To roll out a feature to a percentage of actors, set `key` to `percentage_of_actors` and `value` to
the percentage when you create or update the feature flag.
