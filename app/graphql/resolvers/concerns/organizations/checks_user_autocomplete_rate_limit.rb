# frozen_string_literal: true

module Organizations
  # Rate limits a resolver's user search on the :autocomplete_users budget
  module ChecksUserAutocompleteRateLimit
    private

    def check_search_rate_limit!(search)
      return if search.blank?

      throttled =
        if context[:request]
          ::Gitlab::ApplicationRateLimiter.throttled_request?(
            context[:request], current_user, :autocomplete_users, scope: { user: current_user }
          )
        else
          ::Gitlab::ApplicationRateLimiter.throttled?(:autocomplete_users, scope: { user: current_user })
        end

      return unless throttled

      raise_resource_not_available_error!(::Gitlab::ApplicationRateLimiter.throttled_error_message)
    end
  end
end
