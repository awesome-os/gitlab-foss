# frozen_string_literal: true

module Import
  module Github
    class FindUsableUserCredentialService
      REQUIRED_SCOPES = %w[repo read:org].freeze

      def initialize(user, provider_host:)
        @user = user
        @provider_host = provider_host
      end

      # @return [ServiceResponse] with payload { credential:, login: } for the most recently updated credential
      def execute
        credential = Import::UserCredential
          .most_recently_updated_for_host(user: user, provider: :github, provider_host: provider_host)
          .first

        return unusable('no stored credential') unless credential
        return unusable('missing scopes') unless usable_scopes?(credential)
        # GitLab does not refresh a reused token, so only non-expiring tokens are reused
        return unusable('expiring token') if credential.refresh_token.present? || credential.expires_at.present?

        github_user = Gitlab::GithubImport::Client.new(credential.access_token).octokit.user.to_h
        return unusable('account mismatch') unless github_user[:id] == credential.provider_account_xid

        ServiceResponse.success(payload: { credential: credential, login: github_user[:login] })
      rescue Octokit::Unauthorized
        unusable('token rejected')
      rescue Octokit::Error, Faraday::Error => e
        unusable("GitHub API error: #{e.class.name}")
      end

      private

      attr_reader :user, :provider_host

      def usable_scopes?(credential)
        (REQUIRED_SCOPES - credential.scopes.to_s.split(',').map(&:strip)).empty?
      end

      def unusable(reason)
        Gitlab::GithubImport::Logger.info(
          message: "Not reusing stored GitHub OAuth credential: #{reason}",
          Labkit::Fields::GL_USER_ID => user.id
        )

        ServiceResponse.error(message: reason)
      end
    end
  end
end
