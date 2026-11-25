# frozen_string_literal: true

module Oauth
  class DeviceAuthorizationsController < Doorkeeper::DeviceAuthorizationGrant::DeviceAuthorizationsController
    include Gitlab::Utils::StrongMemoize
    include RequestPayloadLogger

    layout 'minimal'

    def index
      respond_to do |format|
        format.html do
          render "doorkeeper/device_authorization_grant/index"
        end
        format.json { head :no_content }
      end
    end

    def confirm
      return authorization_error_response(:invalid_user_code) if device_grant.nil?
      return authorization_error_response(:expired_user_code) if device_grant.expired?

      @application = device_grant.application
      @scopes = granular_application? ? Gitlab::Auth::GRANULAR_SCOPE.to_s : device_grant.scopes
      respond_to do |format|
        format.html do
          render "doorkeeper/device_authorization_grant/authorize"
        end
        format.json { head :no_content }
      end
    end

    # Overridden from Doorkeeper::DeviceAuthorizationGrant::DeviceAuthorizationsController to record the
    # consent grant of a granular application and narrow the device grant to the granular marker
    def authorize
      return super unless granular_device_grant?
      return authorization_error_response(:granular_consent_failed) unless record_granular_consent

      device_grant.update!(scopes: Gitlab::Auth::GRANULAR_SCOPE.to_s)

      super
    end

    private

    def device_grant
      # rubocop:disable CodeReuse/ActiveRecord -- We are using .find_by here because the models are part of the Doorkeeper gem.
      device_grant_model.find_by(user_code: user_code)
      # rubocop:enable CodeReuse/ActiveRecord
    end
    strong_memoize_attr :device_grant

    def granular_device_grant?
      device_grant.present? && !device_grant.expired? && granular_application?
    end

    def granular_application?
      Feature.enabled?(:granular_oauth_tokens, current_user) && device_grant.application.granular?
    end

    def record_granular_consent
      Authz::OauthConsentGrants::CreateService.new(
        user: current_user, application: device_grant.application, source: :doorkeeper, ip_address: request.remote_ip
      ).execute.success?
    end

    # In Rails 8 alias_method at class-body level fails when the aliased method
    # is not yet in the ancestor chain at load time. Define explicitly instead.
    def auth_user
      current_user
    end
  end
end
