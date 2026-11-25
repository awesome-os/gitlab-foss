# frozen_string_literal: true

class QueueBackfillCatalogResourceComponentInputsOrder < Gitlab::Database::Migration[2.4]
  milestone '19.6'
  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  MIGRATION = "BackfillCatalogResourceComponentInputsOrder"
  BATCH_SIZE = 1000
  SUB_BATCH_SIZE = 100
  # Each job reads component templates from Gitaly, so the batch optimizer must not grow jobs without bound.
  MAX_BATCH_SIZE = 5_000

  def up
    queue_batched_background_migration(
      MIGRATION,
      :catalog_resource_components,
      :id,
      batch_size: BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE,
      max_batch_size: MAX_BATCH_SIZE
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :catalog_resource_components, :id, [])
  end
end
