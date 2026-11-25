# frozen_string_literal: true

class IncreaseSourceCommitLimitOnResourceStateEvents < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  disable_ddl_transaction!

  TABLE_NAME = :resource_state_events
  OLD_CONSTRAINT_NAME = 'check_f0bcfaa3a2'

  def up
    # SHA-256 commit IDs are 64 characters. NOT VALID because the table is large;
    # the constraint is validated asynchronously.
    add_text_limit TABLE_NAME, :source_commit, 64,
      constraint_name: check_constraint_name(TABLE_NAME, :source_commit, 'max_length_64'),
      validate: false

    remove_text_limit TABLE_NAME, :source_commit, constraint_name: OLD_CONSTRAINT_NAME
  end

  def down
    # no-op: restoring the 40-character limit would fail if any row has since
    # been written with a SHA-256 source_commit.
  end
end
