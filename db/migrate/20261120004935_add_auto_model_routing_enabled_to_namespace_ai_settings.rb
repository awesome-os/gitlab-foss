# frozen_string_literal: true

class AddAutoModelRoutingEnabledToNamespaceAiSettings < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :namespace_ai_settings, :auto_model_routing_enabled, :boolean
  end
end
