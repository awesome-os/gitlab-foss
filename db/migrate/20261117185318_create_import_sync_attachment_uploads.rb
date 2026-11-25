# frozen_string_literal: true

class CreateImportSyncAttachmentUploads < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    create_table :import_sync_attachment_uploads do |t|
      t.references :project, null: false
      # The unique index below leads with import_sync_repository_id, so it also serves the foreign key.
      t.references :import_sync_repository, null: false, index: false
      t.references :upload, null: false
      t.timestamps_with_timezone null: false
      t.binary :url_digest, null: false
      # url_digest holds a raw SHA256 (32 bytes), not its 64-character hex form.
      t.check_constraint 'octet_length(url_digest) <= 32', name: 'check_import_sync_attachment_uploads_url_digest_size'

      t.index [:import_sync_repository_id, :url_digest],
        unique: true,
        name: 'idx_import_sync_attachment_uploads_on_repository_url_digest'
    end
  end
end
