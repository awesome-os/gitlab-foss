# frozen_string_literal: true

class CreateMlCandidateLatestMetrics < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def up
    create_table :ml_candidate_latest_metrics do |t|
      t.timestamps_with_timezone null: false
      t.references :candidate, null: false, index: false,
        foreign_key: { to_table: :ml_candidates, on_delete: :cascade }
      t.bigint :project_id, null: false
      t.bigint :experiment_id, null: false
      t.bigint :metric_id, null: false
      t.bigint :tracked_at
      t.float :value, null: false
      t.integer :step
      t.text :name, null: false, limit: 250

      t.index [:candidate_id, :name], unique: true
      t.index [:experiment_id, :name, :value, :candidate_id],
        order: { value: :desc, candidate_id: :desc },
        name: 'index_ml_candidate_latest_metrics_on_experiment_name_value'
      t.index :project_id
    end
  end

  def down
    drop_table :ml_candidate_latest_metrics
  end
end
