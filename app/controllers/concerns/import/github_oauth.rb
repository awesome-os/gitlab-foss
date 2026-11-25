# frozen_string_literal: true

module Import
  module GithubOauth
    extend ActiveSupport::Concern

    OAuthConfigMissingError = Class.new(StandardError)

    included do
      rescue_from OAuthConfigMissingError, with: :missing_oauth_config
    end

    private

    def provider_auth
      return if github_access_token.present?
      return if ci_cd_only? || reuse_user_credential

      go_to_provider_for_permissions
    end

    # Controllers that can reuse a stored credential override this and fill the session.
    def reuse_user_credential
      false
    end

    def ci_cd_only?
      %w[1 true].include?(ci_cd_only_param)
    end

    def ci_cd_only_param
      params.permit(:ci_cd_only)[:ci_cd_only]
    end

    def user_credential_id_key
      :"#{provider_name}_user_credential_id"
    end

    # Scoped to current_user, so a session ID never yields another user's token.
    def reused_user_credential
      credential_id = session[user_credential_id_key]
      return if credential_id.blank?

      # Keyed on the ID: reuse_user_credential can set it mid-request.
      strong_memoize_with(:reused_user_credential, credential_id) do
        current_user.import_user_credentials.find_by_id(credential_id)
      end
    end

    # The OAuth or PAT token in the session, or the token of the stored credential a reuse points at.
    def github_access_token
      session[access_token_key].presence || reused_user_credential&.access_token
    end

    # Import::BaseController defines an identical helper, but this concern is also
    # included by controllers that do not inherit from it.
    def namespace_id_param
      params.permit(:namespace_id)[:namespace_id]
    end

    def go_to_provider_for_permissions
      redirect_to authorize_url
    end

    def oauth_client
      raise OAuthConfigMissingError unless oauth_config

      oauth_client_from_config
    end

    def oauth_client_from_config
      @oauth_client_from_config ||= Gitlab::GithubImport::OauthClient.build(oauth_config)
    end

    def oauth_config
      @oauth_config ||= Gitlab::GithubImport::OauthClient.config
    end

    def authorize_url
      state = SecureRandom.base64(64)
      session[auth_state_key] = state
      session[:auth_on_failure_path] = "#{new_project_path}#import_project"
      oauth_client.auth_code.authorize_url(
        redirect_uri: callback_import_url,
        # read:org is only needed for the optional collaborator import, but the user
        # picks options after this OAuth request, so we always ask for it.
        scope: 'repo, read:org',
        state: state,
        **extra_authorize_params
      )
    end

    def get_token(code)
      oauth_client.auth_code.get_token(code)
    end

    def missing_oauth_config
      session[access_token_key] = nil

      message = _('Missing OAuth configuration for GitHub.')

      respond_to do |format|
        format.json do
          render json: { errors: message }, status: :unauthorized
        end

        format.any do
          redirect_to new_import_url,
            alert: message
        end
      end
    end

    def callback_import_url
      callback_params = extra_import_params.merge({ namespace_id: namespace_id_param })
      # rubocop:disable GitlabSecurity/PublicSend -- route helper name is derived from the provider
      public_send("users_import_#{provider_name}_callback_url", callback_params)
      # rubocop:enable GitlabSecurity/PublicSend
    end

    def extra_import_params
      {}
    end

    def extra_authorize_params
      {}
    end
  end
end
