# frozen_string_literal: true

class AddViolationDetailsToGovernPolicies < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  CONSTRAINT_NAME = 'check_govern_policies_violation_details_size'

  def up
    with_lock_retries do
      add_column :govern_policies, :violation_details, :jsonb, if_not_exists: true
    end

    add_check_constraint :govern_policies, 'octet_length(violation_details::text) <= 65536', CONSTRAINT_NAME
  end

  def down
    with_lock_retries do
      remove_column :govern_policies, :violation_details, if_exists: true
    end
  end
end
