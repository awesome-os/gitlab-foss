# frozen_string_literal: true

module Gitlab
  module Graphql
    module Limit
      # Counts a request against a rate limit once it resolves the field more than `threshold` times.
      # Fields that share a `key` share one call counter per request, including multiplexed queries,
      # which share the request context, so they must use the same threshold.
      # A throttled request fails with `429 Too Many Requests`.
      class FieldCallRateLimit < ::GraphQL::Schema::FieldExtension
        CONTEXT_KEY = :field_call_rate_limits

        def apply
          raise ::ArgumentError, 'Rate limit key must be specified.' unless key
          raise ::ArgumentError, 'Threshold must be specified.' unless threshold
        end

        def resolve(object:, arguments:, context:)
          # A subscription reuses its context for every update, which resolves a single object.
          return yield(object, arguments) if context.query.subscription_update?

          counter = counter_for(context)
          counter.count!
          raise_rate_limited_error! if counter.over_threshold? && counter.throttled? { rate_limit_exceeded?(context) }

          yield(object, arguments)
        end

        private

        def key
          options[:key]
        end

        def threshold
          options[:threshold]
        end

        def counter_for(context)
          counters = context[CONTEXT_KEY] ||= {}
          counters[key] ||= RequestCounter.new(threshold)
        end

        def rate_limit_exceeded?(context)
          scope = rate_limit_scope(context)
          return false unless scope

          ::Gitlab::ApplicationRateLimiter.throttled?(key, scope: scope, **bypass_header_option(context[:request]))
        end

        def rate_limit_scope(context)
          user = context[:current_user]
          return { user: user } if user

          ip = context[:request]&.ip
          { ip: ip } if ip
        end

        # @note Reads the throttle bypass header like `ApplicationRateLimiter.throttled_request?` does.
        def bypass_header_option(request)
          header_name = ::Gitlab::Throttle.bypass_header
          return {} unless request && header_name.present?

          value = request.get_header(header_name)
          value ? { bypass_header: value } : {}
        end

        # @note GraphqlController turns the error into a `429 Too Many Requests` response and logs the request.
        def raise_rate_limited_error!
          raise ::RateLimitedService::RateLimitedError.new(key: key, rate_limiter: ::Gitlab::ApplicationRateLimiter),
            ::Gitlab::ApplicationRateLimiter.throttled_error_message
        end
      end
    end
  end
end
