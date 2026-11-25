# frozen_string_literal: true

module Import
  module Github
    # Refreshes an expiring GitHub OAuth access token stored in a project's import data.
    class RefreshOauthTokenService
      include ::Gitlab::ExclusiveLeaseHelpers
      include ::Gitlab::Utils::StrongMemoize

      class BadRefreshTokenError < ::Octokit::Unauthorized
        private

        def build_error_message
          'GitHub refresh token is invalid or expired. Authorize GitHub again.'
        end
      end

      EXPIRY_MARGIN = 5.minutes
      LEASE_TTL = 1.minute
      LEASE_RETRIES = 25
      LEASE_SLEEP = 0.2
      TRANSIENT_ERRORS = [FailedToObtainLockError, ::OAuth2::Error, ::Faraday::Error].freeze

      # credential_only: sync reads a linked repository's stored credential and never the import-data copy
      # when that credential is missing, blocked or for another host.
      def initialize(project, credential_only: false)
        @project = project
        @credential_only = credential_only
      end

      def refreshable?
        credentials[:refresh_token].present?
      end

      # Returns the stored access token, refreshing it first if it is about to expire. If the
      # refresh fails for a temporary reason, returns the stored token while it is still valid.
      #
      # @return [String, nil]
      def current_token
        token = stored_token
        return token unless refreshable? && expiring?

        execute(token)
      rescue *TRANSIENT_ERRORS
        raise if expired?

        token
      end

      # Returns the stored access token without refreshing it.
      #
      # @return [String, nil]
      def stored_token
        credentials.fetch(:user, nil)
      end

      # Returns the import URL git fetches use, with the linked credential's token when there is one.
      #
      # @return [String, nil]
      def fetch_url
        credential = linked_credential
        return project.unsafe_import_url unless credential

        ::Gitlab::UrlSanitizer.new(project.import_url, credentials: { user: credential.access_token }).full_url
      end

      # Refreshes the token the caller used. If another job already refreshed it, returns the
      # stored token without calling GitHub.
      #
      # @param used_token [String] the access token the caller used
      # @raise [BadRefreshTokenError] if the user must authorize GitHub again
      # @return [String] the new access token
      def execute(used_token)
        in_lock(lease_key, ttl: LEASE_TTL, retries: LEASE_RETRIES, sleep_sec: LEASE_SLEEP) do
          import_data = project.import_data&.reload
          stored = import_data&.credentials || {}
          raise BadRefreshTokenError if stored[:refresh_token].blank?

          next stored[:user] if stored[:user] != used_token

          new_token = refresh(stored)
          import_data.merge_credentials(
            user: new_token.token,
            **::Gitlab::GithubImport::OauthClient.refresh_credentials(new_token)
          )
          import_data.save!

          new_token.token
        end
      end

      # @note Sync fails closed for a missing row, a nil or blocked owner, or another host. Expiring rows
      #   and rows of other users fall back to the import copy, as in imports.
      # @return [Boolean]
      def credential_only?
        return false unless @credential_only && linked_credential_id.present?

        owner = sync_repository_owner
        return false unless ::Feature.enabled?(:github_import_reuse_user_credential, owner)
        return true if owner.nil? || owner.blocked?

        credential = ::Import::UserCredential.find_by_id(linked_credential_id)
        return false if credential && (!credential.non_expiring? || credential.user_id != owner.id)

        true
      end
      strong_memoize_attr :credential_only?

      private

      attr_reader :project, :credential_only

      def credentials
        credential = linked_credential
        return { user: credential.access_token } if credential
        return {} if credential_only?

        project.import_data&.credentials || {}
      end

      def linked_credential_id
        project.import_data&.data&.dig('user_credential_id')
      end

      # The user a linked credential must belong to: the creator, or in EE the user who connected the sync.
      def sync_repository_owner
        project.creator
      end

      # The credential this import is linked to, read only when its token never expires. Only a
      # non-expiring token is reused, since nothing refreshes the stored row. Otherwise, and when the
      # row is missing or for another host, the import uses its copy in import data.
      def linked_credential
        credential_id = linked_credential_id
        return if credential_id.blank?

        credential = ::Import::UserCredential.find_by_id(credential_id)

        unless credential
          Gitlab::GithubImport::Logger.warn(
            message: 'Linked GitHub credential not found, using the import copy',
            Labkit::Fields::GL_PROJECT_ID => project.id
          )
          return
        end

        unless credential.user_id == sync_repository_owner&.id
          Gitlab::GithubImport::Logger.warn(
            message: 'Linked GitHub credential belongs to another user, using the import copy',
            Labkit::Fields::GL_PROJECT_ID => project.id,
            user_credential_id: credential.id
          )
          return
        end

        return unless ::Feature.enabled?(:github_import_reuse_user_credential, credential.user)
        # Sync only: imports keep today's behavior for a blocked owner.
        return if @credential_only && credential.user.blocked?

        unless credential.non_expiring?
          Gitlab::GithubImport::Logger.warn(
            message: 'Linked GitHub credential expires, using the import copy',
            Labkit::Fields::GL_PROJECT_ID => project.id,
            user_credential_id: credential.id
          )
          return
        end

        return credential if host_matches?(credential, import_host) && host_matches?(credential, oauth_host)

        Gitlab::GithubImport::Logger.warn(
          message: 'Linked GitHub credential is for another host, using the import copy',
          Labkit::Fields::GL_PROJECT_ID => project.id,
          user_credential_id: credential.id
        )
        nil
      end
      strong_memoize_attr :linked_credential

      # Same host the credential was stored under: the OAuth config URL, or github.com.
      def oauth_host
        url = ::Gitlab::GithubImport::OauthClient.config&.dig('url').presence || 'https://github.com'
        ::Gitlab::Utils.parse_url(url)&.host&.downcase
      end

      def import_host
        ::Gitlab::Utils.parse_url(project.import_url)&.host&.downcase
      end

      def host_matches?(credential, host)
        host.present? && credential.provider_host == host
      end

      def expiring?
        expires_by?(EXPIRY_MARGIN.from_now)
      end

      def expired?
        expires_by?(Time.current)
      end

      def expires_by?(time)
        expires_at = credentials[:expires_at]
        expires_at.present? && Time.zone.at(expires_at.to_i) <= time
      end

      def refresh(stored)
        client = ::Gitlab::GithubImport::OauthClient.build
        raise BadRefreshTokenError unless client

        ::OAuth2::AccessToken.new(client, stored[:user], refresh_token: stored[:refresh_token]).refresh
      rescue ::OAuth2::Error => e
        raise BadRefreshTokenError if bad_refresh_token?(e)

        raise
      end

      def bad_refresh_token?(error)
        error.code == 'bad_refresh_token' || error.message.include?('bad_refresh_token')
      end

      def lease_key
        "import:github:oauth_token_refresh:#{project.id}"
      end
    end
  end
end

Import::Github::RefreshOauthTokenService.prepend_mod_with('Import::Github::RefreshOauthTokenService')
