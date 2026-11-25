# frozen_string_literal: true

class DropPmPackageVersionLicenses < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  TABLE_NAME = :pm_package_version_licenses

  def up
    drop_table TABLE_NAME, if_exists: true
  end

  # @note The table is recreated empty. Its rows came from the v1 license export,
  #   which stopped being published in 18.0, and nothing read them.
  #   Foreign keys are restored by the down of the migrations that removed them.
  def down
    create_table TABLE_NAME, id: false, if_not_exists: true do |t|
      t.bigint :pm_package_version_id, null: false
      t.bigint :pm_license_id, null: false
      t.timestamps_with_timezone default: -> { 'now()' }, null: false
    end

    # `id` was added after the table existed, so it is the last column. The
    # leading position create_table would give it fails db:check-migrations.
    add_column TABLE_NAME, :id, :primary_key

    add_concurrent_index TABLE_NAME, [:pm_package_version_id, :pm_license_id], unique: true,
      name: 'i_pm_package_version_licenses_join_ids'
    add_concurrent_index TABLE_NAME, :pm_license_id,
      name: 'index_pm_package_version_licenses_on_pm_license_id'
    add_concurrent_index TABLE_NAME, :pm_package_version_id,
      name: 'index_pm_package_version_licenses_on_pm_package_version_id'
  end
end
