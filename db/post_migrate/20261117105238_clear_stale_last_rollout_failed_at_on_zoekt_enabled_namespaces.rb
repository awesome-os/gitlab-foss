# frozen_string_literal: true

class ClearStaleLastRolloutFailedAtOnZoektEnabledNamespaces < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  restrict_gitlab_migration gitlab_schema: :gitlab_main_org
  milestone '19.7'

  BATCH_SIZE = 500

  def up
    enabled_namespaces = define_batchable_model('zoekt_enabled_namespaces')
    replicas = define_batchable_model('zoekt_replicas')
    default_replicas = default_number_of_replicas

    enabled_namespaces.where.not(last_rollout_failed_at: nil).each_batch(of: BATCH_SIZE) do |batch|
      rows = batch.pluck(:id, :number_of_replicas_override)
      replica_counts = replicas.where(zoekt_enabled_namespace_id: rows.map(&:first))
        .group(:zoekt_enabled_namespace_id).count

      provisioned_ids = rows.filter_map do |id, override|
        id if replica_counts.fetch(id, 0) >= (override || default_replicas)
      end
      next if provisioned_ids.empty?

      enabled_namespaces.where(id: provisioned_ids).update_all(last_rollout_failed_at: nil)
    end
  end

  def down
    # no-op: the cleared timestamps recorded failures that a later rollout had already fixed
  end

  private

  def default_number_of_replicas
    value = select_value(<<~SQL).to_i
      SELECT zoekt_settings ->> 'zoekt_default_number_of_replicas'
      FROM application_settings
      ORDER BY id DESC
      LIMIT 1
    SQL

    value > 0 ? value : 1
  end
end
