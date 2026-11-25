# frozen_string_literal: true

module API
  module Entities
    module Clusters
      class Agent < Grape::Entity
        expose :id, documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the agent.' }
        expose :name, documentation: { type: 'String', desc: 'Name of the agent.' }
        expose :project, using: ::API::Entities::ProjectIdentity, as: :config_project,
          documentation: { type: '::API::Entities::ProjectIdentity', desc: 'Project the agent is configured in.' }
        expose :created_at, documentation: { type: 'DateTime', desc: 'Timestamp when the agent was created.' }
        expose :created_by_user_id,
          documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the user who created the agent.' }
      end
    end
  end
end

API::Entities::Clusters::Agent.prepend_mod
