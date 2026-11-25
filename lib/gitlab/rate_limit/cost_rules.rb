# frozen_string_literal: true

module Gitlab
  module RateLimit
    # The rules of the cost-mode limiters (see RackAttack::LabkitRateLimit::Limiters).
    # Unlike the throttles, which count each request as 1 on the way in, these are
    # peeked on the way in and charged a measurement of the request once it
    # finishes. GitLab.com-only, so CE contributes nothing.
    module CostRules
      class << self
        def for_limiter(_limiter_name)
          []
        end
      end
    end
  end
end

::Gitlab::RateLimit::CostRules.prepend_mod
