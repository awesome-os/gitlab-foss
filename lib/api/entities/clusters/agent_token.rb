# frozen_string_literal: true

module API
  module Entities
    module Clusters
      class AgentToken < AgentTokenBasic
        expose :last_used_at, documentation: { type: 'DateTime', desc: 'Timestamp when the token was last used.' }
      end
    end
  end
end
