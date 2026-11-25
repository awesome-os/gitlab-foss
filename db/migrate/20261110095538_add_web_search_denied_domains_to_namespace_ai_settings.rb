# frozen_string_literal: true

class AddWebSearchDeniedDomainsToNamespaceAiSettings < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :namespace_ai_settings, :web_search_denied_domains, :text, default: [], array: true, null: false
  end
end
