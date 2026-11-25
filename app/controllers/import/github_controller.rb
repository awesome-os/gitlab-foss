# frozen_string_literal: true

class Import::GithubController < Import::BaseController
  extend ::Gitlab::Utils::Override

  include ImportHelper
  include SafeFormatHelper
  include ActionView::Helpers::SanitizeHelper
  include Import::GithubOauth

  before_action :verify_import_enabled
  before_action :provider_auth, only: [:status, :realtime_changes, :create]
  before_action :expire_etag_cache, only: [:status, :create]

  rescue_from Octokit::Unauthorized, with: :provider_unauthorized
  rescue_from Octokit::Forbidden, with: :provider_forbidden
  # TooManyRequests subclasses Forbidden, so it must be declared after it to win.
  rescue_from Octokit::TooManyRequests, with: :provider_rate_limit
  rescue_from Gitlab::GithubImport::RateLimitError, with: :rate_limit_threshold_exceeded

  delegate :client, to: :client_proxy, private: true

  PAGE_LENGTH = 25

  def new
    if ::Feature.enabled?(:github_import_reuse_user_credential, current_user)
      new_with_reusable_credential
    elsif github_access_token.present?
      redirect_to status_import_url
    end
  end

  def callback
    auth_state = session.delete(auth_state_key)

    if auth_state.blank? || !ActiveSupport::SecurityUtils.secure_compare(auth_state, callback_params[:state])
      provider_unauthorized
    else
      token = get_token(callback_params[:code])
      session.delete(reuse_suppressed_key)
      session[access_token_key] = token.token
      session[refresh_credentials_key] = Gitlab::GithubImport::OauthClient.refresh_credentials(token).stringify_keys
      session[oauth_token_key] = true
      stored = store_user_credential(token)
      session[reused_user_login_key] = stored&.payload&.dig(:login)
      session[user_credential_id_key] = stored&.payload&.dig(:user_credential_id)
      redirect_to status_import_url
    end
  end

  def personal_access_token
    session.delete(reuse_suppressed_key)
    session[access_token_key] = personal_access_token_param&.strip
    session.delete(oauth_token_key)
    session.delete(refresh_credentials_key)
    session.delete(reused_user_login_key)
    session.delete(user_credential_id_key)
    redirect_to status_import_url
  end

  def status
    respond_to do |format|
      format.json do
        render json: { imported_projects: serialized_imported_projects,
                       provider_repos: serialized_provider_repos,
                       incompatible_repos: serialized_incompatible_repos,
                       page_info: client_repos_response[:page_info],
                       provider_repo_count: client_repos_response[:count] }
      end

      format.html do
        namespace_id = namespace_id_param
        if namespace_id.present?
          @namespace = Namespace.find_by_id(namespace_id)

          render_404 unless Ability.allowed?(current_user, :import_projects, @namespace)
        end
      end
    end
  end

  def details; end

  def create
    import_service = Import::GithubService.new(client, current_user, import_params)
    import_service.request_channel = ::Gitlab::Import::RequestChannel::UI
    result = import_service.execute(access_params, provider_name)

    if result[:status] == :success
      render json: serialized_imported_projects(result[:project])
    else
      render json: { errors: result[:message] }, status: result[:http_status]
    end
  end

  def realtime_changes
    Gitlab::PollingInterval.set_header(response, interval: 3_000)

    render json: Import::GithubRealtimeRepoSerializer.new.represent(already_added_projects)
  end

  def failures
    return render_404 unless Ability.allowed?(current_user, :read_project_import, project)

    unless project.import_finished?
      return render status: :bad_request, json: {
        message: _('The import is not complete.')
      }
    end

    failures = project.import_failures.with_external_identifiers
    serializer = Import::GithubFailureSerializer.new.with_pagination(request, response)

    render json: serializer.represent(failures)
  end

  def cancel
    return render_404 unless Ability.allowed?(current_user, :cancel_project_import, project)

    result = Import::Github::CancelProjectImportService.new(project, current_user).execute

    if result[:status] == :success
      render json: serialized_imported_projects(result[:project])
    else
      render json: { errors: result[:message] }, status: result[:http_status]
    end
  end

  def cancel_all
    projects_to_cancel = Project.imported_from(provider_name).created_by(current_user).is_importing

    canceled = projects_to_cancel.map do |project|
      # #reset is called to make sure project was not finished/canceled before calling service
      result = Import::Github::CancelProjectImportService.new(project.reset, current_user).execute

      {
        id: project.id,
        status: result[:status],
        error: result[:message]
      }.compact
    end

    render json: canceled
  end

  def counts
    render json: {
      owned: client_proxy.count_repos_by('owned', current_user.id),
      collaborated: client_proxy.count_repos_by('collaborated', current_user.id),
      organization: client_proxy.count_repos_by('organization', current_user.id)
    }
  end

  protected

  override :importable_repos
  def importable_repos
    client_repos.to_a
  end

  override :incompatible_repos
  def incompatible_repos
    []
  end

  override :provider_name
  def provider_name
    :github
  end

  override :provider_url
  def provider_url
    oauth_config&.dig('url').presence || 'https://github.com'
  end
  strong_memoize_attr :provider_url

  private

  def project
    @project ||= Project.imported_from(provider_name).find(project_id_param)
  end

  def callback_params
    params.permit(:state, :code)
  end

  def personal_access_token_param
    params.permit(:personal_access_token)[:personal_access_token]
  end

  def project_id_param
    params.permit(:project_id)[:project_id]
  end

  def import_params
    permitted_params = params.permit(permitted_import_params)

    unless oauth_token? && ::Feature.enabled?(:github_continuous_import, current_user)
      permitted_params[:optional_stages]&.delete(:continuous_sync)
    end

    permitted_params
  end

  def permitted_import_params
    [:repo_id, :new_name, :target_namespace, { optional_stages: {} }]
  end

  def serialized_imported_projects(projects = already_added_projects)
    ProjectSerializer.new.represent(
      projects,
      serializer: :import, provider_url: provider_url, client: client_proxy
    )
  end

  def expire_etag_cache
    Gitlab::EtagCaching::Store.new.tap do |store|
      store.touch(realtime_changes_path)
    end
  end

  def client_proxy
    @client_proxy ||= Gitlab::GithubImport::Clients::Proxy.new(github_access_token)
  end

  def client_repos_response
    @client_repos_response ||= client_proxy.repos(sanitized_filter_param, fetch_repos_options)
  end

  def client_repos
    # Request repos to display error page if provider token is invalid
    # Improving in https://gitlab.com/gitlab-org/gitlab-foss/issues/55585
    client_repos_response[:repos]
  end

  def sanitized_filter_param
    super

    @filter = sanitize_query_param(@filter)
  end

  def sanitize_query_param(value)
    value.to_s.first(255).gsub(/[ :]/, '')
  end

  def verify_import_enabled
    render_404 unless import_enabled?
  end

  def import_enabled?
    __send__("#{provider_name}_import_enabled?") # rubocop:disable GitlabSecurity/PublicSend
  end

  def realtime_changes_path
    public_send("realtime_changes_import_#{provider_name}_path", format: :json) # rubocop:disable GitlabSecurity/PublicSend
  end

  def new_import_url
    public_send("new_import_#{provider_name}_url", extra_import_params.merge({ namespace_id: namespace_id_param })) # rubocop:disable GitlabSecurity/PublicSend -- provider_name comes from the subclass definition, not user input
  end

  def status_import_url
    public_send("status_import_#{provider_name}_url", extra_import_params.merge({ namespace_id: namespace_id_param.presence })) # rubocop:disable GitlabSecurity/PublicSend -- provider_name comes from the subclass definition, not user input
  end

  def provider_unauthorized
    session[access_token_key] = nil
    session.delete(user_credential_id_key)
    session[reuse_suppressed_key] = true
    flash[:alert] = s_('Import|Invalid credentials')
    respond_to do |format|
      format.json { render json: { error: { redirect: new_import_url } }, status: :not_found }
      format.html { redirect_to new_import_url }
    end
  end

  def provider_rate_limit(exception)
    reset_time = Time.zone.at(exception.response_headers['x-ratelimit-reset'].to_i)
    session[access_token_key] = nil
    session.delete(user_credential_id_key)
    session[reuse_suppressed_key] = true
    redirect_to new_import_url,
      alert: safe_format(_("GitHub API rate limit exceeded. Try again after %{reset_time}"), reset_time: reset_time)
  end

  def provider_forbidden
    session[access_token_key] = nil
    session.delete(user_credential_id_key)
    session[reuse_suppressed_key] = true
    docs_link = helpers.link_to(
      '',
      help_page_url('user/project/import/github.md', anchor: 'use-a-github-personal-access-token'),
      target: '_blank',
      rel: 'noopener noreferrer'
    )
    tag_pair_docs_link = tag_pair(docs_link, :link_start, :link_end)
    alert_message = safe_format(
      s_(
        "GithubImport|Your GitHub personal access token does not have the required scope to import. " \
          "%{link_start}Learn More%{link_end}."
      ),
      tag_pair_docs_link
    )

    redirect_to new_import_url, alert: alert_message
  end

  def auth_state_key
    :"#{provider_name}_auth_state_key"
  end

  def access_token_key
    :"#{provider_name}_access_token"
  end

  def oauth_token_key
    :"#{provider_name}_oauth_token"
  end

  def refresh_credentials_key
    :"#{provider_name}_refresh_credentials"
  end

  def oauth_token?
    session[oauth_token_key].present?
  end
  helper_method :oauth_token?

  def store_user_credential(token)
    store_credential = ::Feature.enabled?(:github_continuous_import, current_user) ||
      ::Feature.enabled?(:github_import_reuse_user_credential, current_user)
    return unless store_credential
    return if provider_host.blank?
    return if impersonation_in_progress?

    Import::Github::StoreUserCredentialService
      .new(current_user, token, provider_host: provider_host)
      .execute
  end

  def provider_host
    Gitlab::Utils.parse_url(provider_url)&.host
  end

  # Set when a token fails in a rescue handler, so the redirect to new does not reuse it again.
  def reuse_user_credential
    return false if reauthorize_param || session[reuse_suppressed_key]
    # Never hand the impersonated user's stored GitHub token to an admin's session.
    return false if impersonation_in_progress?
    return false unless ::Feature.enabled?(:github_import_reuse_user_credential, current_user)
    # Skip the GitHub check on every request; rescue handlers drop the ID if GitHub rejects the token.
    return true if reused_user_credential

    result = Import::Github::FindUsableUserCredentialService.new(current_user, provider_host: provider_host).execute
    unless result.success?
      session.delete(user_credential_id_key)
      return false
    end

    credential = result.payload[:credential]
    # Only the ID stays in the session; the token is read from the stored credential on each request.
    session[user_credential_id_key] = credential.id
    # Other paths clear only the token, so refresh details from an earlier sign-in can linger.
    session.delete(refresh_credentials_key)
    session[oauth_token_key] = true
    session[reused_user_login_key] = result.payload[:login]
    Gitlab::GithubImport::Logger.info(
      message: 'Reused stored GitHub OAuth credential',
      Labkit::Fields::GL_USER_ID => current_user.id
    )
    true
  end

  def reauthorize_param
    %w[1 true].include?(params.permit(:reauthorize)[:reauthorize])
  end

  # The landing page (Authorize with GitHub or PAT) is shown unless a token is
  # in session or a stored credential can be reused.
  def new_with_reusable_credential
    if reauthorize_param && !ci_cd_only? && github_import_configured?
      clear_session_credentials
      go_to_provider_for_permissions
    elsif github_access_token.present? || (!ci_cd_only? && github_import_configured? && reuse_user_credential)
      redirect_to status_import_url
    end
  end

  def clear_session_credentials
    session.delete(access_token_key)
    session.delete(refresh_credentials_key)
    session.delete(oauth_token_key)
    session.delete(reused_user_login_key)
    session.delete(reuse_suppressed_key)
    session.delete(user_credential_id_key)
  end

  def reuse_suppressed_key
    :"#{provider_name}_reuse_suppressed"
  end

  # Forces GitHub's account picker, so the link switches accounts instead of
  # silently returning the account signed in on github.com.
  def extra_authorize_params
    reauthorize_param ? { prompt: 'select_account' } : {}
  end

  def reused_user_login_key
    :"#{provider_name}_reused_user_login"
  end

  def reused_user_login
    return unless ::Feature.enabled?(:github_import_reuse_user_credential, current_user)

    session[reused_user_login_key] if github_access_token.present?
  end
  helper_method :reused_user_login

  def github_account_data
    return {} if ci_cd_only? || reused_user_login.blank?

    { github_login: reused_user_login,
      github_reauthorize_path: new_import_github_path(reauthorize: true, namespace_id: namespace_id_param) }
  end
  helper_method :github_account_data

  def access_params
    token_params = { github_access_token: github_access_token }
    return token_params unless oauth_token?

    token_params
      .merge(session[refresh_credentials_key].to_h.symbolize_keys)
      .merge(user_credential_params)
  end

  # Only OAuth sessions carry this; the service still checks the token before linking.
  def user_credential_params
    credential_id = session[user_credential_id_key]
    credential_id.present? ? { user_credential_id: credential_id } : {}
  end

  def rate_limit_threshold_exceeded
    head :too_many_requests
  end

  def fetch_repos_options
    pagination_options.merge(relation_options)
  end

  def pagination_params
    params.permit(:before, :after)
  end

  def pagination_options
    {
      before: pagination_params[:before].presence,
      after: pagination_params[:after].presence,
      first: PAGE_LENGTH
    }
  end

  def relation_params
    params.permit(:relation_type, :organization_login)
  end

  def relation_options
    {
      relation_type: relation_params[:relation_type],
      organization_login: sanitize_query_param(relation_params[:organization_login])
    }
  end
end

Import::GithubController.prepend_mod_with('Import::GithubController')
