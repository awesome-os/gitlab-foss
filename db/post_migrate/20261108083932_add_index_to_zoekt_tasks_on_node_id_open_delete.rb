# frozen_string_literal: true

class AddIndexToZoektTasksOnNodeIdOpenDelete < Gitlab::Database::Migration[2.4]
  include Gitlab::Database::PartitioningMigrationHelpers

  milestone '19.7'

  disable_ddl_transaction!

  TABLE_NAME = :zoekt_tasks
  INDEX_NAME = :index_zoekt_tasks_on_node_id_perform_at_id_open_delete

  WHERE_CLAUSE = 'task_type = 50 AND state IN (0, 1)'

  def up
    add_concurrent_partitioned_index TABLE_NAME, [:zoekt_node_id, :perform_at, :id], where: WHERE_CLAUSE,
      name: INDEX_NAME
  end

  def down
    remove_concurrent_partitioned_index_by_name TABLE_NAME, INDEX_NAME
  end
end
