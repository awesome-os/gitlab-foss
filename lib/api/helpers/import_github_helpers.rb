# frozen_string_literal: true

module API
  module Helpers
    module ImportGithubHelpers
      def client
        @client ||= Gitlab::GithubImport::Client.new(params[:personal_access_token], host: github_host,
          per_page: params[:pagination_limit])
      end

      def github_host
        params[:github_hostname]
      end

      # @note Continuous sync needs the EE service, so without it the stage is dropped. Overridden in EE.
      def prepare_continuous_sync!(import_params)
        import_params[:optional_stages]&.delete(:continuous_sync)
      end

      # @note Overridden in EE to set how the user authenticates to GitHub.
      def configure_import_service(_import_service); end

      def access_params
        {
          github_access_token: params[:personal_access_token]
        }
      end

      def provider
        :github
      end

      def github_import_boundary
        import_target_boundary(Namespace.find_by_full_path(params[:target_namespace]))
      end

      def provider_unauthorized
        error!("Wrong credentials", 401)
      end

      def too_many_requests
        error!('Too Many Requests', 429)
      end
    end
  end
end
