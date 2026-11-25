# frozen_string_literal: true

class RemoveKindDefaultFromAiCatalogItemConsumers < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def up
    change_column_default :ai_catalog_item_consumers, :kind, from: 0, to: nil
  end

  def down
    change_column_default :ai_catalog_item_consumers, :kind, from: nil, to: 0
  end
end
