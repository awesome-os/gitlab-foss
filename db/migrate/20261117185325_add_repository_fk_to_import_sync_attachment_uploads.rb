# frozen_string_literal: true

class AddRepositoryFkToImportSyncAttachmentUploads < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  def up
    add_concurrent_foreign_key :import_sync_attachment_uploads, :import_sync_repositories,
      column: :import_sync_repository_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :import_sync_attachment_uploads, column: :import_sync_repository_id
    end
  end
end
