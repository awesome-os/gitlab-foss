# frozen_string_literal: true

module Import
  module Github
    class StoreUserCredentialService
      # @param host [String, nil] GitHub API host for GitHub Enterprise; nil means github.com
      # @param github_user [Hash, nil] the authenticated GitHub user, when the caller already fetched it
      def initialize(user, token, provider_host:, host: nil, github_user: nil)
        @user = user
        @token = token
        @provider_host = provider_host
        @host = host
        @github_user = github_user
      end

      # @return [ServiceResponse]
      def execute
        github_user = @github_user || Gitlab::GithubImport::Client.new(token.token, host: host).octokit.user.to_h

        credential = Import::UserCredential.store!(
          user: user,
          provider: :github,
          provider_host: provider_host,
          provider_account_xid: github_user[:id],
          **token_attributes
        )

        ServiceResponse.success(payload: { login: github_user[:login], user_credential_id: credential.id })
      rescue Octokit::Error, Faraday::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        Gitlab::GithubImport::Logger.error(
          message: 'Failed to store GitHub OAuth credential',
          Labkit::Fields::ERROR_TYPE => e.class.name,
          Labkit::Fields::GL_USER_ID => user.id
        )

        ServiceResponse.error(message: 'Failed to store the GitHub OAuth credential')
      end

      private

      attr_reader :user, :token, :provider_host, :host

      def token_attributes
        refresh_token_expires_in = token['refresh_token_expires_in']

        {
          access_token: token.token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at && Time.zone.at(token.expires_at),
          refresh_token_expires_at: refresh_token_expires_in && refresh_token_expires_in.to_i.seconds.from_now,
          scopes: token['scope']
        }
      end
    end
  end
end
