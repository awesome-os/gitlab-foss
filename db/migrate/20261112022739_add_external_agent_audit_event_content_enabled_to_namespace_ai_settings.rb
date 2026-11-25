# frozen_string_literal: true

class AddExternalAgentAuditEventContentEnabledToNamespaceAiSettings < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :namespace_ai_settings, :external_agent_audit_event_content_enabled, :boolean,
      default: true, null: false
  end
end
