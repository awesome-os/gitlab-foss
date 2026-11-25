# frozen_string_literal: true

module Gitlab
  module Graphql
    module Limit
      # Shared rate limit for the `participants` and `subscribed` fields. Resolving either one walks
      # every note of the item, so a request that does it for many items is expensive.
      # Takes no options: the key and threshold are the same for every guarded field.
      class ParticipantFieldsRateLimit < FieldCallRateLimit
        RATE_LIMIT_KEY = :graphql_participant_fields
        THRESHOLD = 20
        DESCRIPTION = "Requests that resolve the `participants` and `subscribed` fields more than #{THRESHOLD} " \
          'times in total count toward a rate limit. When the `graphql_participant_fields_rate_limit` ' \
          'feature flag is disabled, requests over the limit are only logged.'.freeze

        private

        def key
          RATE_LIMIT_KEY
        end

        def threshold
          THRESHOLD
        end
      end
    end
  end
end
