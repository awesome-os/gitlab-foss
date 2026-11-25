# frozen_string_literal: true

module Ci
  module Catalog
    module BundledResources
      class FetchService
        def initialize(server_fqdn:, full_path:, semver:, name:)
          @server_fqdn = server_fqdn
          @full_path = full_path
          @semver = semver
          @name = name
        end

        def execute
          return not_found unless server_fqdn.to_s.casecmp?(::Gitlab.config.gitlab.server_fqdn)

          component = ::Ci::Catalog::BundledResource.find_bundled_component(
            server_fqdn: server_fqdn, full_path: full_path, semver: semver, name: name
          )
          return not_found unless component&.file_sha256

          project = ::Project.find_by_full_path(component.bundled_resource.full_path)
          return not_found unless Eligibility.eligible?(project)

          ServiceResponse.success(
            payload: {
              bundled_resource: component.bundled_resource,
              version: component.version,
              component: component,
              content: component.file.read
            }
          )
        end

        private

        attr_reader :server_fqdn, :full_path, :semver, :name

        def not_found
          ServiceResponse.error(message: 'Bundled component not found', reason: :not_found)
        end
      end
    end
  end
end
