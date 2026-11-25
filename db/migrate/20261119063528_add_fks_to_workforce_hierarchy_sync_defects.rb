# frozen_string_literal: true

class AddFksToWorkforceHierarchySyncDefects < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  def up
    # Workforce::Hierarchy.delete_for_tenant removes defects in batches first, so the cascades are a backstop only.
    add_concurrent_foreign_key :workforce_hierarchy_sync_defects, :workforce_hierarchies,
      column: :workforce_hierarchy_id, on_delete: :cascade
    add_concurrent_foreign_key :workforce_hierarchy_sync_defects, :namespaces, column: :group_id, on_delete: :cascade
    add_concurrent_foreign_key :workforce_hierarchy_sync_defects, :organizations,
      column: :organization_id, on_delete: :cascade
  end

  def down
    # One block per key, so a rollback never locks two referenced tables in the same transaction.
    %i[workforce_hierarchy_id group_id organization_id].each do |column|
      with_lock_retries do
        remove_foreign_key_if_exists :workforce_hierarchy_sync_defects, column: column
      end
    end
  end
end
