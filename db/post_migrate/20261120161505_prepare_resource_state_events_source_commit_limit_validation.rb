# frozen_string_literal: true

class PrepareResourceStateEventsSourceCommitLimitValidation < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  TABLE_NAME = :resource_state_events

  def up
    prepare_async_check_constraint_validation TABLE_NAME, name: constraint_name
  end

  def down
    unprepare_async_check_constraint_validation TABLE_NAME, name: constraint_name
  end

  private

  def constraint_name
    check_constraint_name(TABLE_NAME, :source_commit, 'max_length_64')
  end
end
