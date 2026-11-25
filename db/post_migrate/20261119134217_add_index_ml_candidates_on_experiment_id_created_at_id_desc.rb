# frozen_string_literal: true

class AddIndexMlCandidatesOnExperimentIdCreatedAtIdDesc < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  INDEX_NAME = 'index_ml_candidates_on_experiment_id_created_at_id_desc'

  def up
    add_concurrent_index :ml_candidates, [:experiment_id, :created_at, :id],
      order: { created_at: :desc, id: :desc },
      name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :ml_candidates, INDEX_NAME
  end
end
