# frozen_string_literal: true

class AddWebSearchDeniedDomainsSizeConstraints < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  CONSTRAINTS = {
    namespace_ai_settings: 'check_namespace_ai_settings_web_search_denied_domains_size',
    ai_settings: 'check_ai_settings_web_search_denied_domains_size'
  }.freeze

  def up
    CONSTRAINTS.each do |table, name|
      add_check_constraint table, 'CARDINALITY(web_search_denied_domains) <= 100', name
    end
  end

  def down
    CONSTRAINTS.each do |table, name|
      remove_check_constraint table, name
    end
  end
end
