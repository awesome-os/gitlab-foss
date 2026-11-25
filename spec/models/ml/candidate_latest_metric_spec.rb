# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ml::CandidateLatestMetric, feature_category: :mlops do
  describe 'associations' do
    it { is_expected.to belong_to(:candidate) }
    it { is_expected.to belong_to(:experiment) }
    it { is_expected.to belong_to(:project) }
  end

  describe '.insert_metrics' do
    let_it_be(:candidate) { create(:ml_candidates) }

    let(:metrics) do
      [
        { name: 'loss', value: 0.5, step: 0, tracked_at: 1000 },
        { name: 'accuracy', value: 0.8, step: 0, tracked_at: 1000 },
        { name: 'loss', value: 0.25, step: 1, tracked_at: 2000 }
      ]
    end

    let(:latest_rows) { described_class.where(candidate: candidate) }

    subject(:insert_metrics) { described_class.insert_metrics(candidate, metrics) }

    it 'inserts every metric with the project of the candidate' do
      expect { insert_metrics }.to change { candidate.metrics.count }.by(3)
      expect(candidate.metrics.distinct.pluck(:project_id)).to eq([candidate.project_id])
    end

    it 'stores the metric that the latest scope returns for each name' do
      insert_metrics

      expected = Ml::CandidateMetric.latest.where(candidate: candidate)
        .map { |metric| [metric.id, metric.name, metric.value, metric.step, metric.tracked_at] }

      expect(latest_rows.pluck(:metric_id, :name, :value, :step, :tracked_at)).to match_array(expected)
      expect(latest_rows.distinct.pluck(:experiment_id, :project_id))
        .to eq([[candidate.experiment_id, candidate.project_id]])
    end

    context 'when a name already has a latest row' do
      let!(:existing_row) do
        described_class.insert_metrics(candidate, [{ name: 'loss', value: 1.0, step: 0, tracked_at: 0 }])
        latest_rows.find_by(name: 'loss')
      end

      it 'updates the row to the new metric' do
        insert_metrics

        expect(existing_row.reload).to have_attributes(value: 0.25, step: 1, tracked_at: 2000)
      end
    end

    it 'reads the experiment with a key share lock on the run' do
      recorder = ActiveRecord::QueryRecorder.new { insert_metrics }

      expect(recorder.log).to include(
        a_string_matching(/SELECT experiment_id FROM ml_candidates WHERE id = #{candidate.id} FOR KEY SHARE/)
      )
    end

    context 'when the run moved to another experiment after it was loaded' do
      let!(:existing_row) do
        described_class.insert_metrics(candidate, [{ name: 'loss', value: 1.0, step: 0, tracked_at: 0 }])
        latest_rows.find_by(name: 'loss')
      end

      let(:new_experiment) { create(:ml_experiments, project: candidate.project) }

      it 'stores the experiment of the run in new and updated rows' do
        Ml::Candidate.id_in(candidate.id).update_all(experiment_id: new_experiment.id)

        insert_metrics

        expect(latest_rows.pluck(:name, :experiment_id))
          .to contain_exactly(['loss', new_experiment.id], ['accuracy', new_experiment.id])
        expect(existing_row.reload.experiment_id).to eq(new_experiment.id)
      end
    end

    context 'when the latest row points to a newer metric than the inserted ones' do
      let!(:existing_row) do
        newer_metric = create(:ml_candidate_metrics, id: non_existing_record_id, candidate: candidate, name: 'loss')
        create(:ml_candidate_latest_metrics, metric: newer_metric)
      end

      it 'keeps the newer metric' do
        insert_metrics

        expect(existing_row.reload.metric_id).to eq(non_existing_record_id)
      end
    end

    context 'when a metric has no value' do
      let(:metrics) { [{ name: 'loss', value: nil, step: 0, tracked_at: 0 }] }

      it 'inserts the metric without a latest row' do
        expect { insert_metrics }.to change { candidate.metrics.count }.by(1)
        expect(latest_rows).to be_empty
      end

      context 'when the name already has a latest row' do
        let!(:existing_row) do
          described_class.insert_metrics(candidate, [{ name: 'loss', value: 1.0, step: 0, tracked_at: 0 }])
          latest_rows.find_by(name: 'loss')
        end

        it 'keeps the previous value' do
          expect { insert_metrics }.not_to change { existing_row.reload.attributes }
        end
      end
    end

    context 'when a value is NaN' do
      let(:metrics) { [{ name: 'loss', value: Float::NAN, step: 0, tracked_at: 0 }] }

      it 'stores NaN' do
        insert_metrics

        expect(latest_rows.sole.value).to be_nan
      end
    end

    context 'when a metric has no name' do
      let(:metrics) { [{ name: 'loss', value: 1.0, step: 0, tracked_at: 0 }, { name: nil, value: 1.0 }] }

      it 'raises an error' do
        expect { insert_metrics }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end

    context 'when there are no metrics' do
      let(:metrics) { [] }

      it 'runs no query' do
        expect(ActiveRecord::QueryRecorder.new { insert_metrics }.count).to eq(0)
      end
    end
  end

  describe '.sync_experiment' do
    let(:candidate) { create(:ml_candidates) }
    let!(:row) { create(:ml_candidate_latest_metrics, metric: create(:ml_candidate_metrics, candidate: candidate)) }
    let!(:other_row) { create(:ml_candidate_latest_metrics) }

    it 'moves the rows of the run to the experiment of the run' do
      candidate.update!(experiment: create(:ml_experiments, project: candidate.project))

      expect { described_class.sync_experiment(candidate) }
        .to change { row.reload.experiment_id }.to(candidate.experiment_id)
        .and not_change { other_row.reload.experiment_id }
    end

    it 'updates only the rows that are in another experiment' do
      candidate.update!(experiment: create(:ml_experiments, project: candidate.project))
      create(:ml_candidate_latest_metrics, metric: create(:ml_candidate_metrics, candidate: candidate))

      expect(described_class.sync_experiment(candidate)).to eq(1)
    end
  end
end
