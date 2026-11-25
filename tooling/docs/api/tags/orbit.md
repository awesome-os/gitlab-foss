---
name: Orbit
external_docs: https://docs.gitlab.com/api/orbit/
---
Use this API to query [GitLab Orbit](https://docs.gitlab.com/orbit/),
which indexes a group's software development lifecycle.
It runs queries and named queries, searches for entities, and retrieves entity context and skills.
This reference does not include `GET /orbit/grep` or `POST /orbit/mcp`.

## Rate limits

The Orbit query rate limit allows 60 requests per minute for each user by default.
Administrators can change the limit and exclude users.

These requests count toward the limit:

- `GET /orbit/grep`
- `POST /orbit/context`
- `POST /orbit/query`
- `POST /orbit/query/:name`
- `GET /orbit/skills`, `GET /orbit/skills/:name`, and `GET /orbit/skills/:name/*path`, including `HEAD` requests
- The `query_graph` command on the MCP endpoint `POST /orbit/mcp`

When you exceed the limit, the endpoint returns `429 Too Many Requests` with a `Retry-After` header.

## Endpoint status

Each endpoint has its own status. Experiment endpoints can change or be removed without notice.
`GET /orbit/grep` and `POST /orbit/context` are experiments. The query and skills endpoints are generally available.

## Query errors

`POST /orbit/query` and `POST /orbit/query/:name` can return these errors.
When Orbit reports a query error, the body is JSON with `code` and `message`.

- `400 Bad Request`: The request is not valid, or the query does not compile or fails validation.
  For a query error, `code` is `compile_error`, `validation_error`, or `invalid_request`.
- `401 Unauthorized`: The request has no valid token.
- `402 Payment Required`: Your Orbit credits are used up. The JSON body has `code` `quota_exhausted`,
  `message`, and `reason` `GITLAB_CREDITS_EXHAUSTED`.
- `403 Forbidden`: Orbit is not available for you, or you have no Orbit-enabled group.
- `404 Not Found`: Orbit is not configured on the instance.
- `422 Unprocessable Entity`: On GitLab.com, you must select a default group for Orbit billing.
  The JSON body has `code` `billing_namespace_required`, `message`, `deep_link` to your preferences,
  and `candidates`, the groups you can select.
- `429 Too Many Requests`: You exceeded the Orbit query rate limit.
- `502 Bad Gateway`: Orbit could not run the query, or the connection to Orbit failed. The body is JSON
  with `code` `execution_error` or `internal_error`, or plain text when the connection failed.
- `504 Gateway Timeout`: The query did not finish in time. `code` is `timeout` when Orbit reports it.

## Skills

Skill endpoints require authentication with the `read_api` or `ai_workflows` scope.
They do not check the Orbit license, so unavailable skills return `404 Not Found` instead of `403 Forbidden`.
The response is `404 Not Found` with the message `Skills are not available` when:

- The Orbit service is an older version without skill RPCs.
- The Orbit service is not configured on the instance. On GitLab Self-Managed, this is
  controlled by `orbit.enabled` in `gitlab.yml`.
- The current user does not have at least the Reporter role in a group whose top-level group has Orbit
  turned on. Administrators in Admin Mode and auditors are exempt from this role requirement.

In these cases, the Orbit CLI uses its embedded local skill.

A skill name must start with a lowercase letter or digit, and contain only lowercase letters, digits, and hyphens.
Other values return `400 Bad Request`.
