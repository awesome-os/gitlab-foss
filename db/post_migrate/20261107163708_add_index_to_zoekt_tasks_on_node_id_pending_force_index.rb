# frozen_string_literal: true

class AddIndexToZoektTasksOnNodeIdPendingForceIndex < Gitlab::Database::Migration[2.4]
  include Gitlab::Database::PartitioningMigrationHelpers

  milestone '19.7'
  disable_ddl_transaction!

  TABLE_NAME = :zoekt_tasks
  INDEX_NAME = :index_zoekt_tasks_on_node_id_pending_force_index
  # 0 is Search::Zoekt::Taskable's `pending` state and 1 is Search::Zoekt::Task's `force_index_repo` type.
  # Must match the predicate RepoToReindexEventWorker counts, so the index stays the size of the queued reindex set.
  WHERE_CLAUSE = 'state = 0 AND task_type = 1'

  def up
    add_concurrent_partitioned_index TABLE_NAME, :zoekt_node_id, where: WHERE_CLAUSE, name: INDEX_NAME
  end

  def down
    remove_concurrent_partitioned_index_by_name TABLE_NAME, INDEX_NAME
  end
end
