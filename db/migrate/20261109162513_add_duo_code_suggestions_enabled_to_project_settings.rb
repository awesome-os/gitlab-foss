# frozen_string_literal: true

class AddDuoCodeSuggestionsEnabledToProjectSettings < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :project_settings, :duo_code_suggestions_enabled, :boolean, null: false, default: true
  end
end
