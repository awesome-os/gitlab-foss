# frozen_string_literal: true

class AddIndexOnRetiringZoektReplicas < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  INDEX_NAME = 'index_zoekt_replicas_on_enabled_namespace_id_retiring'

  def up
    add_concurrent_index :zoekt_replicas, :zoekt_enabled_namespace_id,
      where: 'retiring_at IS NOT NULL', name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :zoekt_replicas, INDEX_NAME
  end
end
