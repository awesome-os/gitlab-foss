# frozen_string_literal: true

class AddExperimentForeignKeyToMlCandidateLatestMetrics < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :ml_candidate_latest_metrics, :ml_experiments,
      column: :experiment_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :ml_candidate_latest_metrics, column: :experiment_id
    end
  end
end
