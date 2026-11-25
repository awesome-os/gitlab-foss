# frozen_string_literal: true

class DropVirtualRegistriesPackagesMavenCacheEntries < Gitlab::Database::Migration[2.4]
  include Gitlab::Database::PartitioningMigrationHelpers::TableManagementHelpers
  include Gitlab::Database::PartitioningMigrationHelpers::IndexHelpers

  disable_ddl_transaction!

  milestone '19.7'

  TABLE_NAME = :virtual_registries_packages_maven_cache_entries

  def up
    with_lock_retries do
      drop_table TABLE_NAME, if_exists: true
    end
  end

  # Recreates the table exactly as it was before the drop, including the
  # partition indexes that were added with the partitioning helpers.
  def down
    create_table TABLE_NAME, if_not_exists: true,
      options: 'PARTITION BY HASH (relative_path)',
      primary_key: %i[upstream_id relative_path status] do |t|
      t.bigint :group_id, null: false
      t.bigint :upstream_id, null: false
      t.datetime_with_timezone :upstream_checked_at, null: false, default: -> { 'now()' }
      t.timestamps_with_timezone null: false
      t.integer :file_store, null: false, default: 1
      t.integer :size, null: false
      t.integer :status, null: false, default: 0, limit: 2
      t.text :relative_path, null: false, limit: 1024
      t.text :file, null: false, limit: 1024
      t.text :object_storage_key, null: false, limit: 1024
      t.text :upstream_etag, limit: 255
      t.text :content_type, null: false, default: 'application/octet-stream', limit: 255
      t.binary :file_md5
      t.binary :file_sha1, null: false
      t.bigint :downloads_count, null: false, default: 0
      t.datetime_with_timezone :downloaded_at

      t.index :relative_path,
        using: :gin,
        opclass: :gin_trgm_ops,
        name: :idx_vreg_pkgs_maven_cache_entries_on_relative_path_trigram

      t.index %i[group_id status],
        name: :idx_vreg_pkgs_maven_cache_entries_on_group_id_status

      t.index %i[upstream_id relative_path],
        where: 'status = 2',
        name: :idx_vregs_pkgs_mvn_cache_entries_on_pending_upt_id_relpath

      t.index %i[upstream_id created_at],
        where: 'status = 0',
        name: :idx_vregs_pkgs_mvn_cache_entries_on_pending_upt_id_created_at
    end

    # create_hash_partitions is atomic and not idempotent, so skip it on a retry
    # after a later step failed.
    partitions = Gitlab::Database::PostgresPartition.for_parent_table(TABLE_NAME.to_s)
    create_hash_partitions(TABLE_NAME, 16) if partitions.none?

    add_check_constraint TABLE_NAME,
      'file_md5 IS NULL OR octet_length(file_md5) = 16',
      check_constraint_name(TABLE_NAME.to_s, 'file_md5', 'max_length')

    add_check_constraint TABLE_NAME,
      'octet_length(file_sha1) = 20',
      check_constraint_name(TABLE_NAME.to_s, 'file_sha1', 'max_length')

    # Added after the partitions existed, so the partition indexes use the
    # hashed names that the partitioning helpers generate.
    add_concurrent_partitioned_index TABLE_NAME,
      %i[upstream_id status relative_path downloaded_at],
      name: :idx_maven_cache_entries_requiring_cleanup_columns

    add_concurrent_partitioned_index TABLE_NAME,
      %i[relative_path object_storage_key group_id],
      unique: true,
      name: :i_v_pkgs_mvn_cache_entries_on_uniq_object_storage_key_group_id
  end
end
