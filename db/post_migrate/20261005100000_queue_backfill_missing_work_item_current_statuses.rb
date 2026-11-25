# frozen_string_literal: true

class QueueBackfillMissingWorkItemCurrentStatuses < Gitlab::Database::Migration[2.3]
  milestone '19.5'
  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  MIGRATION = "BackfillMissingWorkItemCurrentStatuses"
  BATCH_SIZE = 10_000
  SUB_BATCH_SIZE = 100

  # @note No-op: requeued by RequeueBackfillMissingWorkItemCurrentStatuses.
  def up; end

  def down; end
end
