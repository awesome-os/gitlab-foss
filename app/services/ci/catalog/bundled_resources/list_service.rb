# frozen_string_literal: true

module Ci
  module Catalog
    module BundledResources
      class ListService
        def execute
          components = ::Ci::Catalog::BundledResources::Component
            .select(:id, :name, :file_sha256, :catalog_bundled_resource_id, :catalog_bundled_version_id)
            .for_bundled_resources(eligible_bundled_resources.map(&:id))
            .with_digest
            .with_natural_key
            .ordered_by_id

          ServiceResponse.success(payload: { components: components.map { |component| entry(component) } })
        end

        private

        def eligible_bundled_resources
          bundled_resources = ::Ci::Catalog::BundledResource.for_server_fqdn(server_fqdn).to_a
          projects = ::Project.where_full_path_in(bundled_resources.map(&:full_path)).to_a
          ActiveRecord::Associations::Preloader.new(
            records: projects, associations: [:catalog_resource, :project_feature]
          ).call
          projects = projects.index_by { |project| project.full_path.downcase }

          bundled_resources.select do |bundled_resource|
            Eligibility.eligible?(projects[bundled_resource.full_path])
          end
        end

        def entry(component)
          {
            server_fqdn: component.bundled_resource.server_fqdn,
            full_path: component.bundled_resource.full_path,
            semver: component.version.semver.to_s,
            name: component.name,
            file_sha256: Base64.decode64(component.file_sha256).unpack1('H*')
          }
        end

        def server_fqdn
          ::Gitlab.config.gitlab.server_fqdn
        end
      end
    end
  end
end
