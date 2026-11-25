# frozen_string_literal: true

module Ml
  class CandidateLatestMetric < ApplicationRecord
    belongs_to :candidate, class_name: 'Ml::Candidate'
    belongs_to :experiment, class_name: 'Ml::Experiment'
    belongs_to :project

    scope :for_candidates, ->(candidates) { where(candidate_id: candidates.select(:id)) }

    # @note The WHERE keeps the highest metric_id, so concurrent writes converge regardless of write order. A metric
    #   without a value leaves its name's row as is. The run is read FOR KEY SHARE: experiment_id is in a unique
    #   index, so a promotion's update takes FOR UPDATE, and the two wait for each other.
    def self.insert_metrics(candidate, metrics)
      return if metrics.empty?

      now = Time.current
      values = metrics.map do |metric|
        [
          candidate.id, candidate.project_id, metric[:name], metric[:value], metric[:step], metric[:tracked_at],
          now, now
        ]
      end

      connection.exec_insert_all(<<~SQL, "#{name} Insert")
        WITH inserted_metrics AS (
          INSERT INTO ml_candidate_metrics
            (candidate_id, project_id, name, value, step, tracked_at, created_at, updated_at)
          #{Arel::Nodes::ValuesList.new(values).to_sql}
          RETURNING id, candidate_id, project_id, name, value, step, tracked_at, created_at, updated_at
        )
        INSERT INTO ml_candidate_latest_metrics
          (candidate_id, project_id, experiment_id, metric_id, name, value, step, tracked_at, created_at, updated_at)
        SELECT DISTINCT ON (candidate_id, name)
          candidate_id, project_id,
          (SELECT experiment_id FROM ml_candidates WHERE id = #{connection.quote(candidate.id)} FOR KEY SHARE),
          id, name, value, step, tracked_at, created_at, updated_at
        FROM inserted_metrics
        WHERE value IS NOT NULL
        ORDER BY candidate_id, name, id DESC
        ON CONFLICT (candidate_id, name) DO UPDATE SET
          experiment_id = excluded.experiment_id,
          metric_id = excluded.metric_id,
          value = excluded.value,
          step = excluded.step,
          tracked_at = excluded.tracked_at,
          updated_at = excluded.updated_at
        WHERE excluded.metric_id > ml_candidate_latest_metrics.metric_id
      SQL
    end

    def self.sync_experiment(candidate)
      where(candidate_id: candidate.id)
        .where.not(experiment_id: candidate.experiment_id)
        .update_all(experiment_id: candidate.experiment_id)
    end
  end
end
