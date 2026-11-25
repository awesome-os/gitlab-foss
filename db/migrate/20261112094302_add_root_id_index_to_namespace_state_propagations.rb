# frozen_string_literal: true

class AddRootIdIndexToNamespaceStatePropagations < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  TABLE_NAME = :namespace_state_propagations
  INDEX_NAME = 'idx_namespace_state_propagations_on_root_id_and_id'

  def up
    add_concurrent_index TABLE_NAME, '(traversal_ids[1]), id', name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name TABLE_NAME, INDEX_NAME
  end
end
