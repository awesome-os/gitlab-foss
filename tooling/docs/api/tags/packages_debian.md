---
name: 'Packages: Debian'
external_docs: https://docs.gitlab.com/api/packages/debian_group_distributions/
---
> [!warning]
> These endpoints are under development and are not ready for production use due to limited
> functionality. The package endpoints are used by Debian package clients such as
> [dput](https://manpages.debian.org/stable/dput-ng/dput.1.en.html) and
> [apt-get](https://manpages.debian.org/stable/apt/apt-get.8.en.html), and are generally not meant
> for manual consumption.

Use this API to manage [Debian distributions](../../../../doc/user/packages/debian_repository/_index.md)
for groups and projects, and to publish and retrieve Debian packages. The distribution and package
endpoints are behind feature flags that are disabled by default. Debian group repository support is
still a work in progress. To use the endpoints, a GitLab administrator with access to the GitLab
Rails console must enable the
[group](../../../../doc/api/packages/debian_group_distributions.md#enable-the-debian-group-api) or
[project](../../../../doc/api/packages/debian_project_distributions.md#enable-the-debian-api)
Debian API.

The Release file and package index endpoints have identical routes at two levels. Use the
project-level prefix `/projects/:id/packages/debian` to make requests in a single project's scope,
and the group-level prefix `/groups/:id/-/packages/debian` to make requests in a single group's
scope.

> [!note]
> These endpoints do not adhere to the standard API authentication methods. For the supported headers
> and token types, see the [Debian registry documentation](../../../../doc/user/packages/debian_repository/_index.md).
> Undocumented authentication methods might be removed in the future.
