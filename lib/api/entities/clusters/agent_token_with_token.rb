# frozen_string_literal: true

module API
  module Entities
    module Clusters
      class AgentTokenWithToken < AgentToken
        expose :token,
          documentation: { type: 'String', desc: 'Secret value of the token. Returned only when the token is created.' }
      end
    end
  end
end
