# frozen_string_literal: true

class AddProjectFkToImportSyncAttachmentUploads < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  def up
    add_concurrent_foreign_key :import_sync_attachment_uploads, :projects, column: :project_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :import_sync_attachment_uploads, column: :project_id
    end
  end
end
