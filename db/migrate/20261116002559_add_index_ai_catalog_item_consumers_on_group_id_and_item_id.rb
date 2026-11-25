# frozen_string_literal: true

class AddIndexAiCatalogItemConsumersOnGroupIdAndItemId < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  TABLE_NAME = :ai_catalog_item_consumers
  INDEX_NAME = 'index_ai_catalog_item_consumers_on_group_id_and_item_id'

  def up
    add_concurrent_index TABLE_NAME, %i[group_id ai_catalog_item_id], name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name TABLE_NAME, INDEX_NAME
  end
end
