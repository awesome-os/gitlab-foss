# frozen_string_literal: true

class AddExternalAgentServiceAccountIdToNamespaceAiSettings < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :namespace_ai_settings, :external_agent_service_account_id, :bigint
  end
end
