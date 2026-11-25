# frozen_string_literal: true

module Types
  module PermissionTypes
    # rubocop:disable Gitlab/BoundedContexts -- permission types live in Types::PermissionTypes, like the sibling types
    class Organization < BasePermissionType
      graphql_name 'OrganizationPermissions'

      authorize_granular_token parent_authorizes: :read_organization

      abilities :read_organization
    end
    # rubocop:enable Gitlab/BoundedContexts
  end
end

::Types::PermissionTypes::Organization.prepend_mod
