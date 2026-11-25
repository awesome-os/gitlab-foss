# frozen_string_literal: true

class AddUniqueIndexToAdminRolesUuid < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  INDEX_NAME = 'index_admin_roles_on_uuid'

  def up
    add_concurrent_index :admin_roles, :uuid, unique: true, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :admin_roles, INDEX_NAME
  end
end
