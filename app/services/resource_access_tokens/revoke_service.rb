# frozen_string_literal: true

module ResourceAccessTokens
  class RevokeService < BaseService
    include Gitlab::Utils::StrongMemoize

    RevokeAccessTokenError = Class.new(RuntimeError)

    def initialize(current_user, resource, access_token)
      @current_user = current_user
      @access_token = access_token
      @bot_user = access_token.user
      @resource = resource
    end

    def execute
      return error("#{current_user.name} cannot delete #{bot_user.name}") unless can_destroy_token?
      return error("Failed to find bot user") unless find_member

      access_token.revoke!

      block_bot_without_active_tokens

      log_event

      success("Access token #{access_token.name} has been revoked.")
    rescue StandardError => error
      log_error("Failed to revoke access token for #{bot_user.name}: #{error.message}")
      error(error.message)
    end

    private

    attr_reader :current_user, :access_token, :bot_user, :resource

    def can_destroy_token?
      %w[project group].include?(resource.class.name.downcase) && can?(current_user, :destroy_resource_access_tokens, resource)
    end

    def find_member
      strong_memoize(:member) do
        next false unless resource.is_a?(Project) || resource.is_a?(Group)

        resource.member(bot_user)
      end
    end

    # @note A bot with no active token can't authenticate but stays a member until it is deleted,
    #   by default 30 days later. Blocking it lets project_authorizations refreshes skip it until then.
    # @return [void]
    def block_bot_without_active_tokens
      return unless bot_user.project_bot?
      return unless Feature.enabled?(:block_project_bots_on_last_token_revocation, bot_user)
      return if bot_user.personal_access_tokens.active.exists?

      return unless bot_user.block

      Gitlab::AppJsonLogger.info(
        event: 'project_bot_blocked_on_token_revocation',
        Labkit::Fields::GL_USER_ID => bot_user.id,
        token_id: access_token.id,
        resource_type: resource.class.name.downcase,
        resource_id: resource.id,
        revoked_by_user_id: current_user.id,
        revoked_by_username: current_user.username
      )
    end

    def log_event
      ::Gitlab::AppLogger.info "PROJECT ACCESS TOKEN REVOCATION: revoked_by: #{current_user.username}, project_id: #{resource.id}, token_user: #{access_token.user.name}, token_id: #{access_token.id}"
    end

    def error(message)
      ServiceResponse.error(message: message)
    end

    def success(message)
      ServiceResponse.success(message: message)
    end
  end
end

ResourceAccessTokens::RevokeService.prepend_mod_with('ResourceAccessTokens::RevokeService')
