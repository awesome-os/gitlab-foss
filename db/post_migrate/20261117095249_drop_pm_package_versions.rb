# frozen_string_literal: true

class DropPmPackageVersions < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  TABLE_NAME = :pm_package_versions

  def up
    drop_table TABLE_NAME, if_exists: true
  end

  # @note The table is recreated empty. Its rows came from the v1 license export,
  #   which stopped being published in 18.0, and nothing read them.
  #   Foreign keys are restored by the down of the migrations that removed them.
  def down
    create_table TABLE_NAME, if_not_exists: true do |t|
      t.bigint :pm_package_id, null: false
      t.text :version, null: false, limit: 255
      t.timestamps_with_timezone default: -> { 'now()' }, null: false
    end

    add_concurrent_index TABLE_NAME, [:pm_package_id, :version], unique: true,
      name: 'i_pm_package_versions_on_package_id_and_version'
    add_concurrent_index TABLE_NAME, :pm_package_id,
      name: 'index_pm_package_versions_on_pm_package_id'
  end
end
