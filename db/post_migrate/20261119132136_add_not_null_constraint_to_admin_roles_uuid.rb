# frozen_string_literal: true

class AddNotNullConstraintToAdminRolesUuid < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  def up
    add_not_null_constraint :admin_roles, :uuid
  end

  def down
    remove_not_null_constraint :admin_roles, :uuid
  end
end
