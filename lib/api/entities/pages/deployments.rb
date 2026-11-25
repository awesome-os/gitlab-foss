# frozen_string_literal: true

module API
  module Entities
    module Pages
      class Deployments < Grape::Entity
        expose :created_at, documentation: {
          type: 'DateTime', example: '2024-01-05T18:58:14.916Z', desc: 'Date the deployment was created.'
        }
        expose :url, documentation: {
          type: 'String', example: 'http://group.example.com/project/', desc: 'URL for this deployment.'
        }
        expose :path_prefix, documentation: {
          type: 'String', example: 'mr3', desc: 'Path prefix of this deployment when using parallel deployments.'
        }
        expose :root_directory, documentation: {
          type: 'String', example: 'public', desc: 'Root directory of this deployment.'
        }
      end
    end
  end
end
