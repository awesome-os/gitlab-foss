# frozen_string_literal: true

class FinalizeHkBackfillMissingWorkItemCurrentStatuses < Gitlab::Database::Migration[2.4]
  milestone '19.6'

  disable_ddl_transaction!

  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  # @note No-op: requeued by RequeueBackfillMissingWorkItemCurrentStatuses.
  def up; end

  def down; end
end
