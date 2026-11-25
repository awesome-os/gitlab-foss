# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    # RenameGranularScopePermission renamed start_group_export to start_export, which no
    # assignable permission defines. create_export is the one that holds start_group_export.
    class RenameStartExportPermissionInGranularScopes < BatchedMigrationJob
      include Gitlab::Database::MigrationHelpers::GranularScopePermissions

      RENAMES = {
        'start_export' => 'create_export',
        'start_group_export' => 'create_export'
      }.freeze

      feature_category :permissions
    end
  end
end
