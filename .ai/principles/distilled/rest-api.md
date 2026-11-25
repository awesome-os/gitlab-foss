---
source_checksum: eaeb5fcc786417b2
distilled_at_sha: 181e757c6115422b6b78d6e0052f22b5b2b0f8bc
---
<!-- Auto-generated from docs.gitlab.com by gitlab-ai-principles-distiller — do not edit manually -->

# REST API Principles

## Checklist

### General Structure

- DO NOT use instance variables in API endpoints; use local variables instead
- Use an [Entity](https://gitlab.com/gitlab-org/gitlab/-/tree/master/lib/api/entities) to present every endpoint's payload
- Share implementations (e.g., service classes) between REST and GraphQL APIs where possible
- Wrap all API path helper usages in `expose_path(...)` to support relative URL installations

### Entity Field Definitions

- Include a valid `type` for every exposed field in an entity
- Define field types as strings inside the `documentation` hash (e.g., `documentation: { type: 'Integer', example: 1 }`)
- Ensure the documented type matches the serialized value (a `double precision` column documented as `Integer` serializes as `13.0`, which strict clients reject); cast the value or change the documented type
- Use `format_with` in a `with_options` block to cast several fields the same way; share only serialization options such as `format_with` and `expose_nil`, and set `documentation:` (including `type`) on each `expose` (checked by the `API/EntityFieldType` RuboCop cop)
- Add a `desc` key to the field's `documentation` hash when the field name alone does not explain the value
- Use the `using:` option when exposing a field that references another entity; pass only an `API::Entities::*` constant
- Before expanding a high-impact entity (`UserBasic`, `ProjectIdentity`, `Commit`, etc.), consider a new endpoint with its own entity, then an opt-in field guarded by `if:` and an explicit request parameter; use a feature-bounded entity when neither option fits. Respect the `API/EntityExposureGrowth` cop and its allowlist approval process.
- Name feature-bounded entities after their domain context (e.g., `Ci::JobOwner`), not after the fields they contain (e.g., `UserWithNotificationEmail`)
- DO NOT manually edit `api_entity_exposure_baseline.yml` to allowlist new fields; open a discussion with the API Platform team if a field genuinely belongs on a high-impact entity

### Field and Endpoint Description Text

- Write each field description from the code that sets the value (entity block, model method, presenter, policy, or service), not from the field name; describe what the field does, not what it is called
- List every condition that makes a field `null`, including token scope or permission checks (REST has no scope directives); write `Empty if`, not `Null if`, when the value is never `null` (`expose_nil: true` does not mean the field can be `null`)
- Describe only what the field tracks (find every writer of the attribute) and the filter or permission check the code actually applies (a count can differ from the matching list endpoint)
- Move caveats from code comments into the description, especially when two fields look contradictory
- Name the items of a fixed list (including items EE adds) instead of describing the list; state exactly where an action can go; spell out formulas, how missing values count in aggregates, and one-time conditions
- Write "the current user", not "you" or "the user"
- Give a field the same description in every entity that exposes it, and describe the fields of nested entities too (every rendered entity appears in the API reference)
- Format field names, parameter names, and values as inline code in every description (including endpoint `desc`, `detail`, and parameter `desc`)
- Start each sentence with a capitalized word, not a field name or value
- Use the present tense, and describe the product as it is today (DO NOT use words that suggest the behavior might change)
- Use the same terms as the field names and the terms from the user documentation and UI, not internal class or model names; DO NOT include implementation details callers cannot use
- DO NOT write "at least the Planner role" (Planner is outside the role hierarchy); list the roles instead

### Endpoint Description (Grape DSL)

- Include `desc`, `detail`, `success`, and `tags` in every endpoint's `desc` block
- Begin the `desc` summary with an action verb aligned to the HTTP method (Get, List, Create, Update, Delete)
- Use a string literal or interpolated string for `desc` (DO NOT use a variable or method call)
- Keep the `desc` summary to 120 characters or fewer
- Put additional details (version introduced, feature flag, deprecation) in `detail`, not in `desc`
- Describe behavior that is not obvious from the generated OpenAPI definition (parent-type differences for projects/groups/namespaces, ignored vs `400` on unsupported input, who has permission including exceptions for specific resource types); DO NOT repeat parameter types, `values`, nested `requires`, or the `mutually_exclusive`/`exactly_one_of`/`at_least_one_of`/`all_or_none_of` validators in descriptions
- Use `limit:` for string length limits (OpenAPI shows it as `maxLength`)
- Use `values:` (for example, `values: 1..100`) for numeric ranges so OpenAPI shows `minimum`/`maximum`; DO NOT describe a limit the endpoint does not enforce or a parameter/response that an accepted decision removes
- Use the same description for a parameter shared by sibling endpoints (such as create and update)
- Ensure each `failure` message matches when the endpoint actually returns that code (`authorize!` returns `403`, `not_found!` and `find_project!` return `404`); DO NOT flag a deliberate `404` that hides whether a resource exists (for example, experiment-stage endpoints while their feature flag is disabled)
- DO NOT include lifecycle terms ("experiment", "beta", "GA") in `desc` or `detail` strings; use `route_setting :lifecycle` instead (enforced by the `API/LifecycleInDescription` RuboCop cop)
- Use `route_setting :lifecycle, :experiment` or `route_setting :lifecycle, :beta` for non-GA endpoints
- Use `deprecated true` in the `desc` block when deprecating an endpoint; DO NOT use `route_setting :lifecycle` for deprecation
- Assign at least one tag per endpoint; use plural entity names (for example, `audit_events`, `users`); DO NOT use singular or product-category-coupled names
- Describe each tag in `tooling/docs/api/tags/<tag>.md` (checked by `bundle exec rake gitlab:openapi:v3:validate_tag_docs`, which runs in the Lefthook pre-push hook)
- Use `##` for headings in tag description bodies; for feature-flagged endpoints, add a flag note with `> [!note]` (not `> [!flag]`, which the API reference does not render) that says what callers get while the flag is disabled, and add a named-endpoint history entry for each feature flag change (introduced, moved, enabled by default or on GitLab.com, removed with a link to the removing merge request)
- Treat a tag description as public even when every endpoint with that tag is marked `hidden true`; `hidden true` endpoints are left out of the OpenAPI definition, so check a hidden endpoint's text by temporarily dropping `hidden true`, regenerating with `bin/rake gitlab:openapi:v3:generate`, and reverting both
- Ensure an entity returned by a hidden endpoint is treated as published if any non-hidden endpoint renders it, directly or nested (verify by running `bin/rake gitlab:openapi:v3:generate` and checking whether `openapi_v3.yaml` changes)
- Record the reason next to every `hidden true` endpoint with `route_setting :lifecycle, :experiment`/`:beta`, `route_setting :openapi_hidden_reason, :internal` (only other systems call it), or `route_setting :openapi_hidden_reason, :other_protocol` (protocol OpenAPI cannot describe); place the setting next to each hidden endpoint because Grape clears namespace route settings after each endpoint (enforced by the `API/HiddenEndpointReason` RuboCop cop and `spec/lib/api/every_api_endpoint_documented_spec.rb`)
- Add an API class to `excluded_api_classes` in `config/initializers/gitlab_grape_openapi.rb`, under the comment for its reason (mounting class, internal with a comment naming the caller, or test only), when every endpoint in the class must be left out
- Declare at least one `failure` response (4xx/5xx) in every endpoint's `desc` block using an array of hashes with `code` and optional `message` (enforced by the `API/DescriptionFailureResponse` RuboCop cop)
- Constrain every `String` parameter with `values:`, `limit:`, or `regexp:` to prevent unbounded payloads
- Reference route requirement constants (e.g., `NAMESPACE_OR_PROJECT_REQUIREMENTS`) with a leading `::` (e.g., `::API::NAMESPACE_OR_PROJECT_REQUIREMENTS`) to avoid `NameError` from autoloading the entire API surface
- Use `route_setting :tier, :premium` or `route_setting :tier, :ultimate` for EE endpoints that require a paid tier (values enforced by the `API/RouteSettingTier` RuboCop cop); DO NOT declare a tier for endpoints available on every tier, including CE endpoints
- DO NOT include tier information in `desc` or `detail` strings; use `route_setting :tier` instead (enforced by the `API/TierInDescription` RuboCop cop)
- Declare a tier for every EE endpoint (checked by `ee/spec/lib/api/every_ee_api_endpoint_tier_spec.rb`); list endpoints available on every tier, or still needing a tier decision, with a reason in `ee/spec/support/api/routes_without_tier.yml`

### Endpoint Success Definition

- Include a `success` value in every endpoint's `desc` block
- DO NOT use the `http_codes` option to document the success response (enforced by the `API/DeprecatedHttpCodes` RuboCop cop)
- Pass the `Grape::Entity` class directly or via `model:` for JSON responses; omit `model:` only for no-body responses (204, redirects) or when using `schema:`
- Use `schema:` (a JSON schema file name under `lib/api/schemas`, without `.json`, as an OpenAPI 3.0 Schema Object) when no Grape entity builds the response; test the response with `match_api_schema_file` (for responses written by another service such as Workhorse, test that service's output against the same file)
- Use `is_array true` (direct form) or `is_array: true` (hash form) when the endpoint returns a collection; DO NOT wrap the entity class in an array (`success [Entities::MyEntity]` lists alternative responses, so OpenAPI documents a single object)
- Use `example:` (single) or `examples:` (multiple, named) to illustrate response bodies; both require `model:` (or `schema:`) and are mutually exclusive

### Parameters

- Always use `declared(params, include_parent_namespaces: false)` when passing the params hash to a method call
- Use `params[key]` directly only when accessing a single element
- Define Array types with a `coerce_with` block in Grape v1.3+
- Use the `coerce_nil_params_to_array!` helper in `before` blocks to preserve empty-array behavior for nil Array params

### Passing Options to Grape Methods

- Pass options to `present`, `declared`, and route methods (`get`, `post`, `put`, `patch`, `delete`) as keyword arguments; if you have a Hash variable, splat it (`**options`) — DO NOT pass a plain Hash, as Grape silently ignores it (entity not applied, `feature_category`/`urgency` lost)

### Helpers and Route Formats

- DO NOT call `.helpers` with no arguments on an API class to reuse helpers (raises `NoMethodError` in Grape 3.x); put shared helpers in a named module under `lib/api/helpers/` and include it with `helpers ::API::Helpers::FooHelpers`
- Add a matching `requirements:` constraint next to every `format:` option on a route, using the shared constants `::API::JSON_FORMAT_SUFFIX_REQUIREMENT`, `::API::XML_FORMAT_SUFFIX_REQUIREMENT`, or `::API::TXT_FORMAT_SUFFIX_REQUIREMENT`; if writing the regex manually, keep it unanchored (enforced by `spec/lib/api/every_api_endpoint_spec.rb`)

### HTTP Verbs and Status Codes

- Use `PATCH` when updating some attributes of a resource; use `PUT` when replacing all attributes
- Use HTTP status helpers from `lib/api/helpers.rb` (for example, `not_found!`, `no_content!`) for non-200 responses
- Use `destroy_conditionally!` for `DELETE` requests (returns 204 on success, 412 on stale `If-Unmodified-Since`)

### Breaking Changes

- DO NOT remove or rename fields, arguments, or enum values in REST API v4
- DO NOT remove endpoints or change the content type of any response
- DO NOT add new required arguments to existing endpoints
- DO NOT change the type of existing response fields
- DO NOT change existing authentication, authorization, or header requirements; adding an authentication method is non-breaking only if requests without the new credential type are unaffected.
- DO NOT change any status code other than `500`, except for changes resulting from an additional authentication method when requests without the new credential type remain unaffected.
- DO NOT add new redirects without verifying client redirect-following behavior
- When a feature is removed, return a sensible static value or empty response (silent degradation) unless the feature was the endpoint's primary purpose, in which case return `404 Not Found`
- Document intended deprecations ahead of time following the v4 deprecation guide
- DO NOT leave an endpoint out of the OpenAPI specification while the API still serves it, except for a documented hidden reason; DO NOT mark a generally available endpoint as experiment or beta (the `openapi-breaking-changes` CI job, which runs `oasdiff` on changes to `doc/api/openapi/openapi_v3.yaml`, cannot tell these apart from breaking changes)
- Bump the `gitlab-grape-openapi` gem in its own merge request (the `openapi-breaking-changes` job treats the spec rewrite as generator changes only when the MR changes nothing but `Gemfile`, `Gemfile.next`, their lock files, and `openapi_v3.yaml`); explain in the MR description when a finding only corrects the spec and the API behaves the same

### Experimental and Beta Features

- Add `route_setting :lifecycle, :experiment` and use an off-by-default feature flag for experiment-stage endpoints; return `404 Not Found` / ignore arguments / suppress fields when the flag is off
- Add `route_setting :lifecycle, :beta` and an on-by-default feature flag for beta-stage endpoints
- Document experiment/beta status and the feature flag in API documentation
- DO NOT describe experiment or beta changes in the OpenAPI documentation (use the `hidden` option)
- Remove `route_setting :lifecycle`, the feature flag, and experiment/beta API docs when a feature becomes generally available; add OpenAPI documentation at that point

### N+1 Query Prevention

- Implement a `with_api_entity_associations` scope on models to eager-load associations returned in the API
- Add an `ActiveRecord::QueryRecorder` test for every collection-returning endpoint to verify no N+1 queries are introduced

### File Uploads

- Use Workhorse-assisted uploads for all REST API endpoints that accept file content

### Custom Validators

- Use existing custom validators (`FilePath`, `Git SHA`, `Absence`, `IntegerNoneAny`, `ArrayNoneAny`, `EmailOrEmailList`) for parameter validation before passing values downstream
- Add new custom validators in `lib/api/validations/validators/` inheriting from `Grape::Validations::Validators::Base`; add the class to `config/initializers/grape_validators.rb` so it is loaded in every environment (Grape registers it automatically on load)
- DO NOT modify `@options` in a validator instance or memoize values into instance variables — Grape shares and freezes validator instances across requests, causing `FrozenError` at request time; read options from `@options` and use local variables for any derived values
- Add RSpec tests for new validators in `spec/lib/api/validations/validators/`

### Testing

- Use schema fixtures from `/spec/fixtures/api/schemas` and `match_response_schema` to validate API responses

### Changelog

- Include a changelog entry for all client-facing API changes; internal API changes do not require one

### API Documentation Format

- Every method must include the REST API request with HTTP method (GET, PUT, DELETE) followed by the request path starting with `/`
- Every method must have a detailed description of attributes in a table format, with required attributes listed first, then sorted alphabetically
- Every method must include a cURL example using `https://gitlab.example.com/api/v4/` as the endpoint and `<your_access_token>` as the token placeholder
- Every method must have a detailed description of the response body and a JSON response example
- If endpoint attributes are available only to higher subscription tiers or specific offerings, include this information in the attribute description
- For complex object types, represent sub-attributes with dots, like `project.name` or `projects[].name` for arrays
- For cURL commands: use long option names (`--header` instead of `-H`), declare URLs with the `--url` parameter in double quotes, and use line breaks with `\` for readability
- Include documentation for every new or updated API endpoint in the same merge request (or, if strictly necessary, a follow-up in the same milestone)

### Internal API

- Keep the internal API documentation up to date when changing internal endpoints

## Authoritative sources

For the full picture, see:

- doc/development/api_styleguide.md

