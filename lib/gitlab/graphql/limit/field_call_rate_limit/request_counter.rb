# frozen_string_literal: true

module Gitlab
  module Graphql
    module Limit
      class FieldCallRateLimit
        # Counts the calls to the fields that share a rate limit key in one request, and remembers
        # the result of the rate limit check so the request counts against the limit only once.
        class RequestCounter
          def initialize(threshold)
            @threshold = threshold
            @calls = 0
          end

          def count!
            @calls += 1
          end

          def over_threshold?
            @calls > @threshold
          end

          # @note The block, which checks the rate limit, only runs on the first call.
          def throttled?
            return @throttled if defined?(@throttled)

            @throttled = yield
          end
        end
      end
    end
  end
end
