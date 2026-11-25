# frozen_string_literal: true

class DropOnboardingProgressesTable < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  INDEX_NAME = :index_onboarding_progresses_on_namespace_id

  def up
    drop_table :onboarding_progresses, if_exists: true
  end

  def down
    create_table :onboarding_progresses, if_not_exists: true do |t|
      t.bigint :namespace_id, null: false
      t.timestamps_with_timezone null: false
      t.datetime_with_timezone :merge_request_created_at
      t.datetime_with_timezone :pipeline_created_at
      t.datetime_with_timezone :user_added_at
      t.datetime_with_timezone :trial_started_at
      t.datetime_with_timezone :required_mr_approvals_enabled_at
      t.datetime_with_timezone :code_owners_enabled_at
      t.datetime_with_timezone :issue_created_at
      t.datetime_with_timezone :secure_dependency_scanning_run_at
      t.datetime_with_timezone :secure_dast_run_at
      t.datetime_with_timezone :license_scanning_run_at
      t.datetime_with_timezone :code_added_at
      t.datetime_with_timezone :ended_at
      t.datetime_with_timezone :duo_seat_assigned_at
    end

    add_concurrent_index :onboarding_progresses, :namespace_id, unique: true, name: INDEX_NAME
  end
end
