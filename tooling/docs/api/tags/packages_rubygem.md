---
name: 'Packages: RubyGem'
external_docs: https://docs.gitlab.com/api/packages/rubygems/
---
Use this API to interact with the [Ruby gems and Bundler package manager clients](../../../../doc/user/packages/rubygems_registry/_index.md).

> [!warning]
> This API is used by the Ruby gems and Bundler package manager clients and is generally not meant
> for manual consumption. This API is under development and is not ready for production use due to
> limited functionality.

These endpoints do not adhere to the standard API authentication methods.
See the [Ruby gems registry documentation](../../../../doc/user/packages/rubygems_registry/_index.md)
for details on which headers and token types are supported. Undocumented authentication methods might be removed in the future.

These endpoints are behind a feature flag named `rubygem_packages`, disabled by default. GitLab
administrators with access to the GitLab Rails console can enable or disable the flag for the
instance, or for specific projects.
