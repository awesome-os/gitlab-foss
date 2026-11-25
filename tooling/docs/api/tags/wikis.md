---
name: Wikis
external_docs: https://docs.gitlab.com/api/group_wikis/
---
Use this API to manage [project wikis](../../../../doc/user/project/wiki/_index.md) and
[group wikis](../../../../doc/user/project/wiki/group.md).

Comments on a wiki page are called `notes`. To interact with them, use the notes API for
[project wikis](../../../../doc/api/notes.md#project-wikis) or [group wikis](../../../../doc/api/notes.md#group-wikis).

A rate limit applies to unauthenticated requests that list or retrieve wiki pages. This rate limit is
behind a feature flag named `wiki_read_unauthenticated_rate_limit_enforce`, disabled by default.
