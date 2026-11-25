# frozen_string_literal: true

class RemovePmPackageVersionLicensesLicenseFk < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  TABLE_NAME = :pm_package_version_licenses
  TARGET_TABLE_NAME = :pm_licenses
  FK_NAME = :fk_rails_7520ea026d

  def up
    with_lock_retries do
      remove_foreign_key_if_exists TABLE_NAME, TARGET_TABLE_NAME,
        column: :pm_license_id, name: FK_NAME, reverse_lock_order: true
    end
  end

  def down
    add_concurrent_foreign_key TABLE_NAME, TARGET_TABLE_NAME,
      column: :pm_license_id, on_delete: :cascade, name: FK_NAME
  end
end
