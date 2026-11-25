# frozen_string_literal: true

class QueueRenameStartExportPermissionInGranularScopes < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  MIGRATION = 'RenameStartExportPermissionInGranularScopes'

  def up
    queue_batched_background_migration(
      MIGRATION,
      :granular_scopes,
      :id
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :granular_scopes, :id, [])
  end
end
