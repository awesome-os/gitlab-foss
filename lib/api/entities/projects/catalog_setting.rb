# frozen_string_literal: true

module API
  module Entities
    module Projects
      # Exposes the CI/CD Catalog setting for a project. Kept out of the base
      # `Entities::Project` entity to avoid growing its exposure surface.
      module CatalogSetting
        extend ActiveSupport::Concern

        included do
          # Matches the visibility of `Types::ProjectType#is_catalog_resource` in the GraphQL
          # API, which has no extra authorization beyond the caller already being able to
          # view the project.
          expose(:cicd_catalog_enabled, documentation: {
            type: 'Boolean',
            desc: 'Whether the project is published to the CI/CD Catalog. ' \
              '[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/463043) in GitLab 19.3.'
          }) do |project, _options|
            project.catalog_resource.present?
          end
        end
      end
    end
  end
end
