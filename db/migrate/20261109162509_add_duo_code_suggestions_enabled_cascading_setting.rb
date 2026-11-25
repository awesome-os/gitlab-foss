# frozen_string_literal: true

class AddDuoCodeSuggestionsEnabledCascadingSetting < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  include Gitlab::Database::MigrationHelpers::CascadingNamespaceSettings

  def up
    add_cascading_namespace_setting :duo_code_suggestions_enabled, :boolean, default: true, null: false
  end

  def down
    remove_cascading_namespace_setting :duo_code_suggestions_enabled
  end
end
