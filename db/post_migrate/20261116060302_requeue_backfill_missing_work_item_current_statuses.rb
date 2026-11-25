# frozen_string_literal: true

class RequeueBackfillMissingWorkItemCurrentStatuses < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  MIGRATION = "BackfillMissingWorkItemCurrentStatuses"
  BATCH_SIZE = 10_000
  SUB_BATCH_SIZE = 100

  def up
    # Importers write no status row, so items imported after the first run fixed its range have none.
    # When that run finished, only the ids added since then need another pass.
    min_cursor = finished_max_cursor&.then { |(max_id)| [max_id + 1] }
    max_id = select_value('SELECT MAX(id) FROM issues') if min_cursor
    max_cursor = [max_id] if max_id

    delete_batched_background_migration(MIGRATION, :issues, :id, [])

    queue_batched_background_migration(
      MIGRATION,
      :issues,
      :id,
      batch_size: BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE,
      min_cursor: min_cursor,
      max_cursor: max_cursor
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :issues, :id, [])
  end

  private

  def finished_max_cursor
    migration = Gitlab::Database::BackgroundMigration::BatchedMigration
      .find_for_configuration(:gitlab_main_org, MIGRATION, :issues, :id, [], include_compatible: true)
    return unless migration&.finished? || migration&.finalized?

    migration.max_cursor
  end
end
