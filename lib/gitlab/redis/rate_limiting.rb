# frozen_string_literal: true

module Gitlab
  module Redis
    class RateLimiting < ::Gitlab::Redis::Wrapper
      class << self
        # The data we store on RateLimiting used to be stored on Cache.
        def config_fallback
          Cache
        end

        def log_if_using_cache_config
          return unless params.except(:custom) == config_fallback.params.except(:custom)

          Gitlab::AppLogger.info(
            message: "Rate limiting Redis uses the same config as #{config_fallback.store_name}",
            store: store_name,
            fallback_store: config_fallback.store_name
          )
        end

        # Rescue Redis errors so we do not take the site down when the rate limiting instance is down
        def with_suppressed_errors(&block)
          with(&block)
        rescue ::Redis::BaseError, ::RedisClient::Error => e
          Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e)
        end
      end
    end
  end
end
