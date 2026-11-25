# frozen_string_literal: true

class ValidateEventsShardingKeyConstraint < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.6'

  COLUMNS = %i[group_id project_id personal_namespace_id].freeze
  CONSTRAINT_NAME = 'check_5766fc2949'

  def up
    validate_multi_column_not_null_constraint :events, *COLUMNS, constraint_name: CONSTRAINT_NAME
  end

  # Postgres cannot un-validate a constraint, so re-add it as NOT VALID to restore the prior schema
  def down
    remove_multi_column_not_null_constraint :events, *COLUMNS, constraint_name: CONSTRAINT_NAME
    add_multi_column_not_null_constraint :events, *COLUMNS, constraint_name: CONSTRAINT_NAME, validate: false
  end
end
