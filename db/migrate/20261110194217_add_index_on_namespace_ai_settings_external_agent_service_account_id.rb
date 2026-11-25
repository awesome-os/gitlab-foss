# frozen_string_literal: true

class AddIndexOnNamespaceAiSettingsExternalAgentServiceAccountId < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  INDEX_NAME = 'idx_namespace_ai_settings_on_external_agent_service_account_id'

  # @note Only root groups that configure an external agent service account set this column.
  def up
    add_concurrent_index :namespace_ai_settings, :external_agent_service_account_id,
      name: INDEX_NAME, where: 'external_agent_service_account_id IS NOT NULL'
  end

  def down
    remove_concurrent_index_by_name :namespace_ai_settings, INDEX_NAME
  end
end
