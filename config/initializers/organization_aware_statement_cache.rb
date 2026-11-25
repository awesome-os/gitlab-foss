# frozen_string_literal: true

# rubocop:disable Gitlab/AvoidCurrentOrganization -- we need it for the StatementCache
module OrganizationAwareStatementCache
  def cached_find_by_statement(connection, key, &block)
    # The organization filter is baked into the cached statement, so an entry is
    # only reusable while isolation stays enabled for the same organization.
    cache_key = if ::Gitlab::Organizations::Isolation.enabled?
                  [key, ::Current.organization.id]
                else
                  key
                end

    # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Patching existing method
    cache = @find_by_statement_cache[connection.prepared_statements]
    cache.compute_if_absent(cache_key) { ActiveRecord::StatementCache.create(connection, &block) }
    # rubocop:enable Gitlab/ModuleWithInstanceVariables
  end
end
# rubocop:enable Gitlab/AvoidCurrentOrganization

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Core::ClassMethods.prepend(::OrganizationAwareStatementCache)
end
