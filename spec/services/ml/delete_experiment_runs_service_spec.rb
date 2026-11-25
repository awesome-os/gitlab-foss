# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ml::DeleteExperimentRunsService, :aggregate_failures, feature_category: :mlops do
  let_it_be(:project) { create(:project) }
  let_it_be(:other_candidate) { create(:ml_candidates, :with_metrics_and_params, project: project) }

  let(:experiment) { create(:ml_experiments, project: project) }
  let!(:candidates) do
    create_list(:ml_candidates, 3, :with_metrics_and_params, :with_metadata, experiment: experiment, project: project)
  end

  let(:max_rows) { 1_000 }
  let(:runtime_limiter) { Gitlab::Metrics::RuntimeLimiter.new(1.minute) }
  let(:service) { described_class.new(experiment, max_rows: max_rows, runtime_limiter: runtime_limiter) }

  before do
    stub_const("#{described_class}::BATCH_PAUSE", 0)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    it 'deletes the runs and their metrics, params and metadata, and keeps the experiment' do
      candidate_ids = candidates.map(&:id)

      expect(execute.payload).to eq(completed: true)

      expect(Ml::Candidate.where(id: candidate_ids)).to be_empty
      expect(Ml::CandidateMetric.where(candidate_id: candidate_ids)).to be_empty
      expect(Ml::CandidateParam.where(candidate_id: candidate_ids)).to be_empty
      expect(Ml::CandidateMetadata.where(candidate_id: candidate_ids)).to be_empty
      expect(other_candidate.reload.metrics.count).to eq(2)
      expect(experiment.reload).to be_present
      expect(service.deleted_rows).to eq(21)
    end

    it 'deletes the runs in batches' do
      stub_const("#{described_class}::BATCH_SIZE", 2)

      recorder = ActiveRecord::QueryRecorder.new { execute }

      expect(recorder.log.grep(/\ADELETE FROM "ml_candidates"/).size).to eq(2)
    end

    it 'deletes the latest metrics in sub-batches before the metrics, and keeps those of other runs' do
      candidates.each { |candidate| create(:ml_candidate_latest_metrics, metric: candidate.metrics.first) }
      other_row = create(:ml_candidate_latest_metrics, metric: other_candidate.metrics.first)
      stub_const("#{described_class}::RUN_CHILDREN_SUB_BATCH_SIZES",
        described_class::RUN_CHILDREN_SUB_BATCH_SIZES.merge(Ml::CandidateLatestMetric => 2))

      recorder = ActiveRecord::QueryRecorder.new { execute }
      latest_metric_deletes = recorder.log.grep(/\ADELETE FROM "ml_candidate_latest_metrics"/)

      expect(latest_metric_deletes.size).to eq(2)
      expect(latest_metric_deletes).to all(include('LIMIT 2'))
      expect(recorder.log.index { |q| q.start_with?('DELETE FROM "ml_candidate_latest_metrics"') })
        .to be < recorder.log.index { |q| q.start_with?('DELETE FROM "ml_candidate_metrics"') }
      expect(Ml::CandidateLatestMetric.where(candidate_id: candidates.map(&:id))).to be_empty
      expect(other_row.reload).to be_present
    end

    it 'deletes the metrics, params and metadata in sub-batches of their own size before the runs' do
      stub_const("#{described_class}::RUN_CHILDREN_SUB_BATCH_SIZES",
        { Ml::CandidateMetric => 4, Ml::CandidateParam => 4, Ml::CandidateMetadata => 5 })

      recorder = ActiveRecord::QueryRecorder.new { execute }
      metric_and_param_deletes = recorder.log.grep(/\ADELETE FROM "ml_candidate_(metrics|params)"/)
      metadata_deletes = recorder.log.grep(/\ADELETE FROM "ml_candidate_metadata"/)

      # 6 rows per table: two statements per table
      expect(metric_and_param_deletes.size).to eq(4)
      expect(metric_and_param_deletes).to all(include('LIMIT 4'))
      expect(metadata_deletes.size).to eq(2)
      expect(metadata_deletes).to all(include('LIMIT 5'))
      expect(recorder.log.index { |q| q.start_with?('DELETE FROM "ml_candidate_metadata"') })
        .to be < recorder.log.index { |q| q.start_with?('DELETE FROM "ml_candidates"') }
    end

    context 'when the deletion reaches max_rows' do
      let(:max_rows) { 7 }

      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it 'stops after the batch that reaches the limit' do
        expect { execute }.to change { experiment.candidates.count }.from(3).to(2)

        expect(execute.payload).to eq(completed: false)
        expect(service.deleted_rows).to eq(7)
      end
    end

    context 'when the deletion runs out of time while deleting the children of a batch' do
      before do
        stub_const("#{described_class}::RUN_CHILDREN_SUB_BATCH_SIZES",
          described_class::RUN_CHILDREN_SUB_BATCH_SIZES.transform_values { 1 })
        allow(runtime_limiter).to receive(:over_time?).and_return(true)
        candidates.each { |candidate| create(:ml_candidate_latest_metrics, metric: candidate.metrics.first) }
      end

      it 'stops after one statement and keeps the runs' do
        expect { execute }.to change { Ml::CandidateLatestMetric.where(candidate: candidates).count }.from(3).to(2)
          .and not_change { Ml::CandidateMetric.where(candidate: candidates).count }

        expect(execute.payload).to eq(completed: false)
        expect(experiment.candidates.count).to eq(3)
      end
    end
  end
end
