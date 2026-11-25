# frozen_string_literal: true

module API
  module Entities
    module Clusters
      class AgentTokenBasic < Grape::Entity
        expose :id, documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the token.' }
        expose :name, documentation: { type: 'String', desc: 'Name of the token.' }
        expose :description, documentation: { type: 'String', desc: 'Description of the token.' }
        expose :agent_id,
          documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the agent the token belongs to.' }
        expose :status, documentation: { type: 'String', desc: 'Status of the token. Either `active` or `revoked`.' }
        expose :created_at, documentation: { type: 'DateTime', desc: 'Timestamp when the token was created.' }
        expose :created_by_user_id,
          documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the user who created the token.' }
      end
    end
  end
end
