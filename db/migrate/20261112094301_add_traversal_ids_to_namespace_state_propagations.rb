# frozen_string_literal: true

class AddTraversalIdsToNamespaceStatePropagations < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  # @note The default only fills records seeded outside production (the table is empty there),
  #   and is dropped so inserts must still set traversal_ids.
  def up
    add_column :namespace_state_propagations, :traversal_ids, :bigint, array: true, default: [], null: false
    change_column_default :namespace_state_propagations, :traversal_ids, from: [], to: nil
  end

  def down
    remove_column :namespace_state_propagations, :traversal_ids
  end
end
