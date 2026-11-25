# frozen_string_literal: true

# == CheckRateLimit
#
# Controller concern that checks if the rate limit for a given action is throttled by calling the
# Gitlab::ApplicationRateLimiter class. If the action is throttled for the current user, the request
# will be logged and an error message will be rendered with a Too Many Requests response status.
# See lib/api/helpers/rate_limiter.rb for API version
module CheckRateLimit
  def check_rate_limit!(key, scope:, redirect_back: false, **options)
    return unless Gitlab::ApplicationRateLimiter.throttled_request?(request, current_user, key, scope: scope, **options)

    return yield if block_given?

    message = Gitlab::ApplicationRateLimiter.throttled_error_message

    if redirect_back
      redirect_back_or_default(options: { alert: message })
    else
      render plain: message, status: :too_many_requests
    end
  end

  # Checks the rate limit per user when signed in, and per IP address otherwise.
  #
  # @param key [Symbol] the rate limit key
  # @param options [Hash] options passed to {#check_rate_limit!}
  # @see API::Helpers::RateLimiter#check_rate_limit_by_user_or_ip!
  def check_rate_limit_by_user_or_ip!(key, **options, &block)
    check_rate_limit!(key, scope: current_user ? { user: current_user } : { ip: request.ip }, **options, &block)
  end
end
