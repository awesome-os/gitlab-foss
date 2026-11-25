# frozen_string_literal: true

# Row updates, unlike a table rewrite, reach Siphon. The admin_roles sync
# trigger also copies each UUID to its admin role copy.
class BackfillMemberRolesUuid < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  milestone '19.7'

  def up
    update_column_in_batches(:member_roles, :uuid, Arel.sql('gen_random_uuid_v7()')) do |table, query|
      query.where(table[:uuid].eq(nil))
    end
  end

  def down
    # no-op
  end
end
