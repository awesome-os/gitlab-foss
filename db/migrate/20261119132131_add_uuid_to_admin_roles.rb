# frozen_string_literal: true

# Added without a default so the table isn't rewritten. Setting the default
# afterwards only covers new rows. Existing rows are backfilled post-deploy.
class AddUuidToAdminRoles < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  def up
    with_lock_retries do
      add_column :admin_roles, :uuid, :uuid, if_not_exists: true
      change_column_default :admin_roles, :uuid, from: nil, to: -> { 'gen_random_uuid_v7()' }
    end
  end

  def down
    with_lock_retries do
      remove_column :admin_roles, :uuid, if_exists: true
    end
  end
end
