# frozen_string_literal: true

module ClickHouse # rubocop:disable Gitlab/BoundedContexts -- existing module
  class QueryLimiting
    # Budgets the ClickHouse usage of each user's web requests in the windows set by the
    # click_house_*_by_user rate limits. Usage is charged after each select, so a spent
    # budget rejects the selects that follow, not the one that spent it.
    module UserBudget
      KEYS = %i[
        click_house_read_bytes_by_user
        click_house_read_rows_by_user
        click_house_duration_s_by_user
      ].freeze

      # Web and API controllers render RateLimitedError subclasses as a 429 with #headers.
      # GraphqlController matches exact classes, so it lists this one in ERROR_STATUS_MAP.
      class ExceededError < ::RateLimitedService::RateLimitedError
        # @param key [Symbol] the spent budget
        def initialize(key:)
          super(key: key, rate_limiter: ::Gitlab::ApplicationRateLimiter)
        end

        # The full window: the exact reset time isn't exposed by Gitlab::ApplicationRateLimiter.peek.
        def headers
          { 'Retry-After' => ::Gitlab::ApplicationRateLimiter.period_for(key).to_s }
        end

        def message
          ::Gitlab::ApplicationRateLimiter.throttled_error_message
        end
      end

      class << self
        # @return [Boolean]
        def enabled?
          Gitlab::Runtime.puma? && Feature.enabled?(:click_house_user_query_budget, :instance)
        end

        # Raises when the user of the current request has spent a budget.
        #
        # @raise [ExceededError]
        # @return [void]
        def check_current_user!
          return unless enabled?

          user = current_user
          return unless user

          key = exceeded_key(user)
          raise ExceededError.new(key: key) if key

          nil
        end

        # @param user [User]
        # @return [Symbol, nil] the first spent budget of the user
        def exceeded_key(user)
          Gitlab::SafeRequestStore.fetch(store_key(user)) do
            KEYS.find { |key| Gitlab::ApplicationRateLimiter.peek(key, scope: { user: user }) }
          end
        end

        # Charges a select to the user of the current request, if any.
        #
        # @param read_bytes [Integer]
        # @param read_rows [Integer]
        # @param duration_s [Float]
        # @return [void]
        def charge_current_user!(read_bytes:, read_rows:, duration_s:)
          return unless enabled?

          user = current_user
          return unless user

          charge!(user, read_bytes: read_bytes, read_rows: read_rows, duration_s: duration_s)
        end

        # @param user [User]
        # @param read_bytes [Integer]
        # @param read_rows [Integer]
        # @param duration_s [Float]
        # @return [void]
        def charge!(user, read_bytes:, read_rows:, duration_s:)
          # Past the limit, more charges change nothing: they don't extend the window.
          return if Gitlab::SafeRequestStore[store_key(user)]

          costs = {
            click_house_read_bytes_by_user: read_bytes,
            click_house_read_rows_by_user: read_rows,
            click_house_duration_s_by_user: duration_s
          }

          spent_keys = costs.select do |key, cost|
            cost > 0 && Gitlab::ApplicationRateLimiter.throttled?(key, scope: { user: user }, cost: cost)
          end
          spent_key = spent_keys.each_key.first

          # Reject the rest of this request's selects too, not only the next request's.
          Gitlab::SafeRequestStore[store_key(user)] = spent_key if spent_key

          nil
        end

        private

        # The rate limiter applies GITLAB_THROTTLE_USER_ALLOWLIST only to a User scope,
        # so we load the user once per request instead of passing the ID from the context.
        def current_user
          user_id = Labkit::Context.current&.get_attribute(Labkit::Fields::GL_USER_ID)
          return if user_id.blank?

          # The user is very likely in the query cache already, loaded by the authentication.
          Gitlab::SafeRequestStore.fetch("click_house_user_budget_user:#{user_id}") { User.find_by_id(user_id) }
        end

        def store_key(user)
          "click_house_user_budget_exceeded:#{user.id}"
        end
      end
    end
  end
end
