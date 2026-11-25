/**
 * Collect all context the monolith makes available to a Vue app and return it
 * as a strongly-typed GitLabContext object ready to be passed to an MFE.
 *
 * Sources:
 *  - window.gon        : user, feature flags, licensed features, API config
 *  - <meta csrf-token> : CSRF token for REST / GraphQL mutations
 *  - el.dataset        : page-specific data serialized in HAML data-* attributes
 *
 * The shape is defined by GitLabContextSchema in @gitlab-mfe/context.
 * Any change to that schema must be reflected here. build_gitlab_context_spec.js
 * validates the output against GitLabContextJsonSchema from the same package.
 *
 * @param {HTMLElement} el - The MFE mount element
 * @returns {import('@gitlab-mfe/context').GitLabContext}
 */
export function buildGitLabContext(el) {
  const gon = window.gon ?? {};

  const csrfToken =
    document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '';

  const currentUser = gon.current_user_id
    ? {
        id: gon.current_user_id,
        username: gon.current_username ?? '',
        name: gon.current_user_fullname ?? '',
        avatarUrl: gon.current_user_avatar_url ?? '',
      }
    : null;

  return {
    currentUser,
    features: gon.features ?? {},
    licensedFeatures: gon.licensed_features ?? {},
    // BCP 47 locale tag from <html lang="..."> — set by the Rails layout from
    // the user's language preference. The MFE uses this to load the correct
    // translation file without needing to query the DOM itself.
    locale: document.documentElement.getAttribute('lang') ?? 'en',
    csrfToken,
    apiVersion: gon.api_version ?? 'v4',
    // eslint-disable-next-line @gitlab/no-hardcoded-urls -- reads the gon key, not a URL
    relativeUrlRoot: gon.relative_url_root ?? '',
    gitlabUrl: gon.gitlab_url ?? window.location.origin,
    sentryDsn: gon.sentry_dsn ?? null,
    sentryEnvironment: gon.sentry_environment ?? null,
    // Spread all data-* attributes from the mount element.
    // HAML: #js-mfe-foo{ data: { project_full_path: @project.full_path } }
    // becomes el.dataset.projectFullPath (camelCased by the browser).
    pageData: { ...el.dataset },
  };
}
