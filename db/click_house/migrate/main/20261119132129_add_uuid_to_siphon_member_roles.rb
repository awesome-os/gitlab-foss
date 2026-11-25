# frozen_string_literal: true

class AddUuidToSiphonMemberRoles < ClickHouse::Migration
  def up
    execute <<~SQL
      ALTER TABLE siphon_member_roles ADD COLUMN IF NOT EXISTS uuid Nullable(UUID);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE siphon_member_roles DROP COLUMN IF EXISTS uuid;
    SQL
  end
end
