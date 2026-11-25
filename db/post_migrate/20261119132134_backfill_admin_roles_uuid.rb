# frozen_string_literal: true

# admin_roles rows are copies of member_roles rows with the same id, so they
# get the UUID of their member role. Any other row gets a new UUID.
# See https://gitlab.com/groups/gitlab-org/-/epics/17390
class BackfillAdminRolesUuid < Gitlab::Database::Migration[2.4]
  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  milestone '19.7'

  def up
    execute(<<~SQL)
      UPDATE admin_roles
      SET uuid = member_roles.uuid
      FROM member_roles
      WHERE member_roles.id = admin_roles.id
        AND admin_roles.uuid IS DISTINCT FROM member_roles.uuid
    SQL

    execute(<<~SQL)
      UPDATE admin_roles SET uuid = gen_random_uuid_v7() WHERE uuid IS NULL
    SQL
  end

  def down
    # no-op
  end
end
