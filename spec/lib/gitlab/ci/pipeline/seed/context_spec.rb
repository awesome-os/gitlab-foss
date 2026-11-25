# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Seed::Context, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project) }

  let(:pipeline) { build_stubbed(:ci_pipeline, project: project) }

  subject(:context) { described_class.new(pipeline) }

  describe '#check_execution_time!' do
    context 'when no deadline is set' do
      it 'does not raise' do
        expect { context.check_execution_time! }.not_to raise_error
      end
    end

    context 'when the deadline has not passed' do
      before do
        context.set_deadline(60)
      end

      it 'does not raise' do
        expect { context.check_execution_time! }.not_to raise_error
      end
    end

    context 'when the deadline has passed' do
      before do
        context # Pipeline::Logger reads the clock on init, so build it before stubbing
        allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(100.0, 161.0)

        context.set_deadline(60)
      end

      it 'raises a timeout error' do
        expect { context.check_execution_time! }.to raise_error(described_class::TimeoutError)
      end

      it 'does not count the job candidate as evaluated' do
        expect { context.check_execution_time! }.to raise_error(described_class::TimeoutError)

        expect(context.evaluated_job_candidates_count).to eq(0)
      end
    end
  end

  describe '#evaluated_job_candidates_count' do
    it 'counts the execution time checks' do
      expect { 3.times { context.check_execution_time! } }
        .to change { context.evaluated_job_candidates_count }.from(0).to(3)
    end
  end

  describe '#needs_from_memory?' do
    it 'reads the feature flag once for the pipeline project' do
      stub_feature_flags(ci_pipeline_create_needs_from_memory: true)
      allow(Feature).to receive(:enabled?).and_call_original
      expect(Feature).to receive(:enabled?).with(:ci_pipeline_create_needs_from_memory, project).once.and_call_original

      expect(Array.new(2) { context.needs_from_memory? }).to eq([true, true])
    end

    context 'when the ci_pipeline_create_needs_from_memory feature flag is disabled' do
      before do
        stub_feature_flags(ci_pipeline_create_needs_from_memory: false)
      end

      it { expect(context.needs_from_memory?).to be(false) }
    end
  end
end
