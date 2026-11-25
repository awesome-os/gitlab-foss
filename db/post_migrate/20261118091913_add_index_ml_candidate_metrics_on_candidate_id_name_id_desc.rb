# frozen_string_literal: true

class AddIndexMlCandidateMetricsOnCandidateIdNameIdDesc < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!

  milestone '19.7'

  TABLE_NAME = :ml_candidate_metrics
  INDEX_NAME = 'index_ml_candidate_metrics_on_candidate_id_name_id_desc'

  def up
    add_concurrent_index TABLE_NAME, %i[candidate_id name id], order: { id: :desc }, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name TABLE_NAME, INDEX_NAME
  end
end
