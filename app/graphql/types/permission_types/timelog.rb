# frozen_string_literal: true

module Types
  module PermissionTypes
    class Timelog < BasePermissionType
      graphql_name 'TimelogPermissions'

      authorize_granular_token permissions: :read_timelog,
        boundaries: [
          { boundary: :project, boundary_type: :project },
          { boundary: :namespace, boundary_type: :group }
        ]

      abilities :admin_timelog, :delete_timelog
    end
  end
end
