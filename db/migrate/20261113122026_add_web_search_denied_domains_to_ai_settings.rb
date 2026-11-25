# frozen_string_literal: true

class AddWebSearchDeniedDomainsToAiSettings < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :ai_settings, :web_search_denied_domains, :text, default: [], array: true, null: false
  end
end
