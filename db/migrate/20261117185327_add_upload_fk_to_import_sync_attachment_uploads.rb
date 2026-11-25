# frozen_string_literal: true

class AddUploadFkToImportSyncAttachmentUploads < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  # @note uploads is partitioned by model_type, so the key references the partition that holds FileUploader
  #   uploads, like project_upload_states does.
  def up
    add_concurrent_foreign_key :import_sync_attachment_uploads, :project_uploads,
      column: :upload_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :import_sync_attachment_uploads, column: :upload_id
    end
  end
end
