# frozen_string_literal: true

class RemoveFinalizedIndexFromAnalyticsDevopsAdoptionSnapshots < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  TABLE_NAME = :analytics_devops_adoption_snapshots
  INDEX_NAME = 'idx_analytics_devops_adoption_snapshots_finalized'

  # @note Redundant since the unique index on (namespace_id, end_time) serves the same lookups.
  def up
    remove_concurrent_index_by_name TABLE_NAME, INDEX_NAME
  end

  def down
    add_concurrent_index TABLE_NAME, [:namespace_id, :end_time],
      where: 'recorded_at >= end_time', name: INDEX_NAME
  end
end
