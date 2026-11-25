# frozen_string_literal: true

module API
  module Entities
    module Pages
      class ProjectSettings < Grape::Entity
        expose :url, documentation: {
          type: 'String', example: 'http://group.example.com/project',
          desc: 'URL to access the Pages site for this project.'
        }
        expose :deployments, using: ::API::Entities::Pages::Deployments, documentation: {
          is_array: true, desc: 'List of current active deployments.'
        }
        expose :unique_domain_enabled?, as: :is_unique_domain_enabled, documentation: {
          type: 'Boolean', example: true, desc: 'If `true`, unique domain is enabled.'
        }
        expose :force_https?, as: :force_https, documentation: {
          type: 'Boolean', example: false, desc: 'If `true`, the project is set to force HTTPS.'
        }
        expose :pages_primary_domain, documentation: {
          type: 'String', example: 'https://custom.example.com',
          desc: 'Primary domain that all Pages requests are redirected to. ' \
            '[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/481334) in GitLab 17.8.'
        }
      end
    end
  end
end
