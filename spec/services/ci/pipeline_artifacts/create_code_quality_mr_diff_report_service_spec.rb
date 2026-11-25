# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::PipelineArtifacts::CreateCodeQualityMrDiffReportService, feature_category: :pipeline_reports do
  describe '#execute' do
    let_it_be_with_reload(:merge_request) { create(:merge_request) }
    let_it_be(:project) { merge_request.project }
    let_it_be_with_reload(:head_pipeline) { create(:ci_pipeline, :success, :with_codequality_reports, project: project, merge_requests_as_head_pipeline: [merge_request]) }

    subject { described_class.new(head_pipeline).execute }

    context 'when there are codequality reports' do
      context 'when pipeline passes' do
        context 'when degradations are present' do
          let_it_be(:base_pipeline) do
            create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
              sha: merge_request.diff_base_sha)
          end

          context 'when degradations already present in target branch pipeline' do
            before do
              create(:ci_build, :success, :codequality_reports, name: 'codequality', pipeline: base_pipeline, project: project)
            end

            it "does not persist a pipeline artifact" do
              expect { subject }.not_to change { Ci::PipelineArtifact.count }
            end
          end

          context 'when degradation is not present in target branch pipeline' do
            before_all do
              create(:ci_build, :success, :codequality_reports_without_degradation, name: 'codequality', pipeline: base_pipeline, project: project)
            end

            it 'persists a pipeline artifact once, with default file name, expiry and locked status', :aggregate_failures do
              freeze_time do
                expect { subject }.to change { Ci::PipelineArtifact.count }.by(1)

                pipeline_artifact = Ci::PipelineArtifact.first

                expect(pipeline_artifact).to be_present
                expect(pipeline_artifact.file.filename).to eq('code_quality_mr_diff.json')
                expect(pipeline_artifact.expire_at).to eq(1.week.from_now)
                expect(pipeline_artifact.locked).to eq(head_pipeline.locked)
              end
            end

            it 'records the access of every source report' do
              create(:ci_job_artifact, :codequality, :maintainer_only_access,
                job: create(:ci_build, :failed, pipeline: head_pipeline, project: project))

              subject

              content = Gitlab::Json::SafeParser.parse(Ci::PipelineArtifact.first.file.read)
              expect(content['source_access']).to contain_exactly(%w[public codequality], %w[maintainer codequality])
            end

            it 'does not persist the same artifact twice' do
              subject

              expect { described_class.new(head_pipeline).execute }.not_to change { Ci::PipelineArtifact.count }
            end

            context 'when a report is larger than the size limit' do
              before do
                stub_const('Ci::Artifactable::CODEQUALITY_MAX_BYTES', 1.byte)
              end

              it 'logs the error and does not persist a pipeline artifact' do
                expect(Gitlab::ErrorTracking).to receive(:log_exception)
                  .with(an_instance_of(Ci::JobArtifact::FileTooLargeError), { Labkit::Fields::GL_PIPELINE_ID => head_pipeline.id })

                expect { subject }.not_to change { Ci::PipelineArtifact.count }
              end

              context 'when the codequality_report_size_limit feature flag is disabled' do
                before do
                  stub_feature_flags(codequality_report_size_limit: false)
                end

                it 'persists a pipeline artifact' do
                  expect { subject }.to change { Ci::PipelineArtifact.count }.by(1)
                end
              end
            end
          end
        end
      end
    end

    context 'when there are no codequality reports for head pipeline' do
      let(:head_pipeline) { create(:ci_pipeline, :success, project: project, merge_requests_as_head_pipeline: [merge_request]) }

      it "does not persist a pipeline artifact" do
        expect { subject }.not_to change { Ci::PipelineArtifact.count }
      end
    end

    context 'when there are no codequality reports for base pipeline' do
      it "does not persist a pipeline artifact" do
        expect { subject }.not_to change { Ci::PipelineArtifact.count }
      end
    end
  end
end
