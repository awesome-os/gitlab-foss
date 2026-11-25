# frozen_string_literal: true

class RemoveEventsShardingKeyIsNotNullCheckConstraint < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.6'

  TABLE_NAME = :events
  CONSTRAINT_NAME = 'check_events_sharding_key_is_not_null'

  def up
    remove_check_constraint TABLE_NAME, CONSTRAINT_NAME
  end

  def down
    add_check_constraint TABLE_NAME,
      'group_id IS NOT NULL OR project_id IS NOT NULL OR personal_namespace_id IS NOT NULL',
      CONSTRAINT_NAME
  end
end
