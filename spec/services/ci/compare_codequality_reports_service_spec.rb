# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CompareCodequalityReportsService, feature_category: :continuous_integration do
  let(:service) { described_class.new(project) }
  let_it_be_with_reload(:project) { create(:project) }

  describe '#execute' do
    subject { service.execute(base_pipeline, head_pipeline) }

    context 'when head pipeline has a codequality report' do
      let(:base_pipeline) { nil }
      let(:head_pipeline) { create(:ci_pipeline, :with_codequality_reports, project: project) }

      it 'returns status and data' do
        expect(subject[:status]).to eq(:parsed)
        expect(subject[:data]).to match_schema('entities/codequality_reports_comparer')
      end
    end

    context 'when base and head pipelines have codequality reports' do
      let(:base_pipeline) { create(:ci_pipeline, :with_codequality_reports, project: project) }
      let(:head_pipeline) { create(:ci_pipeline, :with_codequality_reports, project: project) }

      it 'returns status and data' do
        expect(subject[:status]).to eq(:parsed)
        expect(subject[:data]).to match_schema('entities/codequality_reports_comparer')
      end
    end

    context 'when the head report is larger than the size limit' do
      let(:service) { described_class.new(project, create(:user, developer_of: project)) }
      let(:base_pipeline) { nil }
      let(:head_pipeline) { create(:ci_pipeline, :with_codequality_reports, project: project) }

      before do
        stub_const('Ci::Artifactable::CODEQUALITY_MAX_BYTES', 1.byte)
      end

      it 'returns an error status with the reason', :aggregate_failures do
        expect(subject[:status]).to eq(:error)
        expect(subject[:status_reason]).to include('exceeds')
      end

      context 'when the codequality_report_size_limit feature flag is disabled' do
        before do
          stub_feature_flags(codequality_report_size_limit: false)
        end

        it 'returns status and data' do
          expect(subject[:status]).to eq(:parsed)
        end
      end
    end
  end
end
