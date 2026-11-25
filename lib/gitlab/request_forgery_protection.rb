# frozen_string_literal: true

# A module to check CSRF tokens in requests.
# It's used in API helpers and OmniAuth.
# Usage: GitLab::RequestForgeryProtection.call(env)

module Gitlab
  module RequestForgeryProtection
    SAFE_REQUEST_METHODS = %w[GET HEAD].freeze

    class Controller < BaseActionController
      protect_from_forgery with: :exception, prepend: true

      def initialize
        super

        # Squelch noisy and unnecessary "Can't verify CSRF token authenticity." messages.
        # X-Csrf-Token is only one authentication mechanism for API helpers.
        self.logger = ActiveSupport::Logger.new(File::NULL)
      end

      def index
        head :ok
      end
    end

    def self.app
      @app ||= Controller.action(:index)
    end

    def self.call(env)
      app.call(env)
    end

    def self.verified?(env)
      # ActionController's verified_request? is unconditionally true for GET and HEAD, so
      # returning early skips a controller dispatch on every request without a token.
      return true if SAFE_REQUEST_METHODS.include?(env['REQUEST_METHOD']) && skip_dispatch_for_safe_methods?

      minimal_env = env.slice('REQUEST_METHOD', 'rack.session', 'HTTP_X_CSRF_TOKEN')
                      .merge('rack.input' => StringIO.new(''))

      # The CSRF token for some requests is in the form instead of headers.
      # This line of code is used to accommodate this situation. See: https://gitlab.com/gitlab-org/gitlab/-/issues/443398
      minimal_env['HTTP_X_CSRF_TOKEN'] ||= Rack::Request.new(env.dup).params['authenticity_token']

      call(minimal_env)

      true
    rescue ActionController::InvalidAuthenticityToken
      false
    end

    # Reached up to twice per request, so the flag is resolved once and reused.
    def self.skip_dispatch_for_safe_methods?
      Gitlab::SafeRequestStore.fetch(:skip_csrf_dispatch_for_safe_methods) do
        Feature.enabled?(:skip_csrf_dispatch_for_safe_methods, Feature.current_request)
      end
    end
    private_class_method :skip_dispatch_for_safe_methods?
  end
end
