---
name: GLQL
external_docs: https://docs.gitlab.com/api/glql/
---
Use this API to execute [GitLab Query Language (GLQL)](../../../../doc/user/glql/_index.md) queries
programmatically. GLQL provides a simplified query language to search and filter
[GitLab resources](../../../../doc/user/glql/_index.md#supported-areas) such as issues, merge requests,
and epics across projects and groups.

The group or project must allow access to its data. For private groups and projects, you must
authenticate with a [personal access token](../../../../doc/user/profile/personal_access_tokens.md)
that has the appropriate permissions.

The `glql_yaml` parameter takes a GLQL query with optional YAML configuration. Set the `fields`
configuration option to a comma-separated list of [available GLQL fields](../../../../doc/user/glql/fields.md).

The GLQL API rate limits queries based on the SHA-256 hash of the query. Queries that time out are
tracked. If a query that times out is run too often, it is temporarily blocked, and the API returns
`429 Too Many Requests` with the error
`Query temporarily blocked due to repeated timeouts. Please try again later or narrow your search scope.`

`POST /glql` returns these status codes:

- `200 OK`: the query ran successfully.
- `400 Bad Request`: invalid query syntax, configuration that is not YAML key-value pairs, a `query`
  value that is not a string, missing required parameters, or input that exceeds the size limit.
  A project or group that does not exist or that you cannot access returns `400` with the error
  `Project does not exist or you do not have access to it` or
  `Group does not exist or you do not have access to it`. GraphQL bad request errors are passed
  through to the `error` field with the `400` code, when applicable.
- `401 Unauthorized`: authentication is required or the credentials are invalid.
- `403 Forbidden`: insufficient permissions or a missing OAuth scope.
- `429 Too Many Requests`: the query rate limit is exceeded.
- `500 Internal Server Error`: an unexpected server error. This response uses the `message` key
  instead of `error`.
- `503 Service Unavailable`: the query timed out. Narrow the query scope, for example with more
  filters or a shorter time range, and try again.

Limits:

- The `glql_yaml` parameter has a maximum size of 10,000 bytes.
- A request returns at most 100 results. The default is 100 results.
- Only forward pagination is supported, with the `after` attribute set to the `endCursor` value
  from a previous response.
