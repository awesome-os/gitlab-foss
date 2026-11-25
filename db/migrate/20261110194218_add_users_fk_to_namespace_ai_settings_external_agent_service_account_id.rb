# frozen_string_literal: true

class AddUsersFkToNamespaceAiSettingsExternalAgentServiceAccountId < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  def up
    # rubocop:disable Migration/ForeignKeysToDestroyServiceTables -- Users::DestroyService declares handles_removal_of :namespace_ai_settings
    add_concurrent_foreign_key :namespace_ai_settings, :users,
      column: :external_agent_service_account_id,
      on_delete: :nullify
    # rubocop:enable Migration/ForeignKeysToDestroyServiceTables
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :namespace_ai_settings, column: :external_agent_service_account_id
    end
  end
end
