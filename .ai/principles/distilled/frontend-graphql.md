---
source_checksum: 74e5186d76668405
distilled_at_sha: cf64a3d8f7ef3e3137b983ecedac825dcf82a0b3
---
<!-- Auto-generated from docs.gitlab.com by gitlab-ai-principles-distiller — do not edit manually -->

> **Prerequisite:** If you haven't already, also read .ai/principles/distilled/frontend-vue.md - it contains foundational rules that apply to all frontend work.

# Frontend GraphQL Principles

## Checklist

### Libraries and Client

- Use the default client (`createDefaultClient` from `~/lib/graphql`) instead of creating new Apollo clients; it sets the correct URL and CSRF headers
- Use Apollo Client with Vue Apollo for GraphQL on the frontend, and Immer for immutable cache updates
- Create the `VueApollo` provider with the default client at the point where the Vue application is mounted
- Use the default client directly (`defaultClient.query({ query })`) when using GraphQL outside Vue; set `fetchPolicy: fetchPolicies.NO_CACHE` when the data is cached elsewhere or caching is not needed
- Pass a `baseUrl` in `config` only when the GraphQL endpoint differs from the main endpoint
- Define a custom `merge` function or a `merge: true` type policy for a type that has no `id` in the schema when Apollo warns "Cache data may be lost when replacing…" (in unit tests, ensure mocked responses contain an `id` whenever it is requested)

### Query Deduplication

- Opt out of query deduplication with `context: { queryDeduplication: false }` for a query that can be re-dispatched with the same document and variables while an earlier dispatch is in flight and needs a fresh round trip (freshness across a mutation race, per-call `AbortController` or context, or imperative `refetch()`/`client.query()` calls)
- DO NOT disable deduplication for queries that many components fetch at the same time

### Query Files and Naming

- Import `.graphql` files directly so webpack pre-compiles queries
- Name files by operation type: `*.query.graphql`, `*.mutation.graphql`, `*.fragment.graphql`; use `.customer.query.graphql`, `.customer.mutation.graphql`, or `.customer.fragment.graphql` for CustomersDot endpoint operations
- Add a `# @feature_category: <category>` comment at the top of every query, mutation, and subscription file, using a category from `config/feature_categories.yml` (enforced by the `local-rules/graphql-require-feature-category` ESLint rule)
- Use only `high`, `medium`, `default`, or `low` for the optional `# @urgency: <value>` comment (enforced by `local-rules/graphql-require-valid-urgency`)
- Share fields across operations with fragments in separate `.fragment.graphql` files imported via `#import`

### Global IDs

- Use `getIdFromGraphQLId` from `~/graphql_shared/utils` to convert a Global ID to the primary key `id`
- Query the global `id` for every GraphQL type that has an `id` in the schema (DO NOT add `id` for types that have none, such as `PageInfo`)

### Query Shape and Performance

- DO NOT treat query complexity limits as proof that a query is cheap; nested connections inside lists cause per-row resolver calls and authorization checks
- Give a connection selected inside a list a `first:` or `last:` argument (enforced by `local-rules/graphql-no-unbounded-nested-connection`; the rule checks fragments as their own definitions, so verify fragments at their spread sites)
- DO NOT nest selection sets deeper than 8 levels; a connection's `nodes` wrapper counts as a level (enforced by `@graphql-eslint/selection-set-depth` in the `eslint` CI job)
- When a list needs nested data, prefer in order: a field the backend already batches (`BatchLoader::GraphQL`) or preloads (`LooksAhead`), or add batching in a paired backend MR; a bounded nested connection with `first:`; a separate query only for the row the user expands
- Decompose a query that fails the lint rules instead of adjusting it until the rule passes: load nested data on user demand, use a small `first:` page size, query children from a top-level field for the opened item only (DO NOT run the child query for every row), or use a batched field
- DO NOT suppress the GraphQL lint rules unless the fan-out is bounded by something the linter cannot see (such as a parent connection with `first: 1`); use `# eslint-disable-next-line` in the `.graphql` file with a comment explaining why. DO NOT add new queries to the `.eslint_todo/` lists, and add a field to the rule's `allow` option only when it is small and batched everywhere
- Lint `.graphql` changes with `yarn run lint:eslint path/to/file.query.graphql` after running `./scripts/dump_graphql_schema`; when changing a fragment, also lint the operation files that spread it
- Request a backend reviewer (owning group or `@gitlab-org/graphql-experts`) when adding a nested connection or unbounded list to an existing query; route queries reading partitioned or large tables through the database review process
- When a frontend query change is paired with a backend change, add or extend a `QueryRecorder` request spec under `spec/requests/api/graphql/` or `ee/spec/requests/api/graphql/`

### Request Budget and Splitting Queries

- Batch GraphQL queries that fire on page load with a shared descriptive `batchKey` in the query `context` (for example `MRSidebarData`); up to 10 queries are batched per request
- DO NOT split queries unless necessary (query exceeds complexity limits or data loads lazily on user interaction); batch split queries that fire on page load with a shared `batchKey`
- DO NOT batch queries with an explicit `featureCategory` (only one `x-gitlab-feature-category` header is sent per batch) or slow queries (a batch returns only when the slowest query completes)
- Verify in the browser inspector that splitting a query does not cause the same queries to be called multiple times or invalidate existing queries
- Use `@include`/`@skip` directives to split queries conditionally based on component state
- Avoid polling when possible; prefer subscriptions or ETag-based caching

### Vue Apollo Usage

- Declare queries that run on component load as smart queries in the `apollo` property; use `this.$apollo.query()` only when a smart query does not fit (recursive pagination, subscription-triggered fetches)
- Use `update()` to map the response to the component property, `result()` only for side effects, and `skip()` to prevent a query from running
- Define `data` properties for all Apollo queries
- Add a `skip()` to any query whose variables depend on another query's result, covering all dependent values, to avoid running it twice
- Make on-demand queries lazy with a `skip()` condition or `this.$apollo.addSmartQuery`
- DO NOT combine Pinia with Apollo in one application unless restrictions are met (see `state_management.md#combining-pinia-and-apollo`); DO NOT combine Vuex with Apollo, and migrate existing Vuex stores away

### Mutations and Cache Updates

- Use the mutation `update` hook only to add or remove an item in the cache; include the global `id` in the mutation response so updates to existing items apply to the cache automatically
- Treat cache updates as immutable: use Immer `produce`, naming the original cache `sourceData` and the updated cache `data`, then `writeQuery` the result

### Error Handling

- Handle both top-level errors (Promise rejection or `error` event) and errors-as-data (add `errors` to the mutation selection) for mutations
- Define client-side messages for top-level errors; DO NOT show them directly to users
- Use judgment on whether to show the `errors` message from the response or a client-side message for errors-as-data

### Pagination

- Use `pageInfo` (via `page_info.fragment.graphql`) with `after`/`before` plus `first`/`last` for Relay-style cursor pagination
- Use `fetchMore` in a smart query for user-driven pagination; use a non-smart recursive `$apollo.query` to fetch all pages initially
- Keep a `requestCount` capped by `MAX_REQUEST_COUNT` in recursive or `result()`-driven page fetching to avoid infinite requests
- Define a field merge policy in `typePolicies` for paginated fields: replace existing results for Previous/Next buttons; concatenate `nodes` (or use `concatPagination()`) for infinite scroll; always overwrite pagination fields with incoming values
- Set `keyArgs: false` when no field argument is a good cache key (for example, `after` changes per page) and rely on the `merge` function
- Use the `@connection(key: ...)` directive on paginated queries that are read or written via `readQuery`/`writeQuery` to avoid passing pagination variables

### Local State and Frontend-Ahead-of-Backend Work

- Use `@client` fields with local resolvers (passed as the first parameter to `createDefaultClient`) to mock API fields not yet in the backend, and remove the `@client` directive when the API ships
- Use the `@client` directive for new queries, mutations, or fields not yet supported by the backend (skipped by the `graphql-verify` CI job), and track its removal in a follow-up issue
- DO NOT add a file to `config/known_invalid_graphql_queries.yml` when only adding fields to an existing query (use `@client` so the rest is still validated); keep such overrides short-lived and track removal
- Feature-flag the frontend implementation when it is ahead of the backend so it does not cause public-facing errors
- Use `@include`/`@skip` with a feature-flag variable (such as `gon.features`) for feature-flagged query fields; ensure the field exists in the schema and the backend resolver returns `null` when the flag is off
- DO NOT duplicate a query into feature-flagged versions; Exception: when the new entities are not yet in the schema or are feature-flagged at the schema level (`new_entity: :feature_flag`)

### Polling and ETag Caching

- Prefer ETag-based caching over plain Apollo polling; send the `X-GITLAB-GRAPHQL-RESOURCE-ETAG` and related headers via the query `context` with `fetchOptions: { method: 'GET' }`
- Update the ETag resource in the local cache when it changes dynamically
- Pause polling while the tab is hidden with `setupQueryPollingByVisibility`
- Verify ETag caching in the network tab: polled requests should be `GET` with status `304` when nothing changed

### Subscriptions

- Use subscriptions sparingly; use them only for low-latency updates, high-frequency status changes, or large objects where polling is expensive
- Use `subscribeToMore` in the query definition by default; use the `result` hook with a manual `subscribeToMore` only when the subscription target derives from query data, skip logic is complex, or cleanup on data change is needed
- Track subscription state (for example `isSubscribed`) and unsubscribe on change; DO NOT call `subscribeToMore` on every `result()`
- Return only the `id` in subscription payloads and fetch full data separately (signal and fetch)
- Guard network calls in `updateQuery` with `Visibility.hidden()`, and trigger a single `refetch()` when the tab becomes visible; unbind the `Visibility` listener in `beforeDestroy`
- DO NOT fire a network request immediately in `updateQuery` for list views; collect IDs and fetch them with a debounced batcher (capped batch size), canceling the debounce and clearing pending IDs in `beforeDestroy`
- Add visibility-aware ETag polling alongside subscriptions as a safety net for dropped WebSocket connections

### Startup Calls

- Place startup-call queries in `app/graphql/queries`, add `__typename` to every nested level, and inline fragments (or remove single-use fragments) instead of importing them
- Add startup calls in the HAML view with `add_page_startup_graphql_call('<path relative to app/graphql/queries>', { variables })`

### Testing

- Run `bundle exec rake gitlab:graphql:schema:dump` after pulling upstream or rebasing, since some tests load the schema files
- Test Apollo components with a mock Apollo provider from `helpers/mock_apollo_helper` and call `Vue.use(VueApollo)` right after imports; DO NOT mock `$apollo` via `mocks`
- Use `createControlledMockApollo` (named export) for all new tests and resolve operations explicitly with `resolveQuery`, `rejectQuery`, `resolveMutation`, `rejectMutation`, or `resolveAll()`; the default `createMockApollo` export is legacy (auto-resolves) and for existing tests
- Provide a handler for every query and mutation (`jest.fn().mockResolvedValue(...)`); use `mockRejectedValue` for error cases
- Structure mocked responses the same as the real API response (root `data` property) and include `__typename` (or use GraphQL query fixtures) to avoid empty-object results
- Pass mock `resolvers` (second parameter to `createMockApollo`) instead of handlers for `@client` queries
- Populate the cache with `cache.writeQuery` to test the `result` hook of local queries
- Use `mockRejectedValueOnce` when testing subscription errors to avoid infinite re-subscription loops

## Authoritative sources

For the full picture, see:

- doc/development/fe_guide/graphql.md

