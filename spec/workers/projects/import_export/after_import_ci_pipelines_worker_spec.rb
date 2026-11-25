# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ImportExport::AfterImportCiPipelinesWorker, feature_category: :importers do
  let_it_be(:project) { create(:project, :repository) }

  let_it_be_with_reload(:merge_request) do
    create(:merge_request, source_project: project, source_branch: 'feature', target_branch: 'master')
  end

  let_it_be(:pipeline) { create(:ci_pipeline, :detached_merge_request_pipeline, merge_request: merge_request) }

  let(:worker) { described_class.new }

  describe '#perform' do
    it 'runs the service with a runtime limiter' do
      expect_next_instance_of(Projects::ImportExport::LinkMergeRequestHeadPipelinesService, project) do |service|
        expect(service).to receive(:execute)
          .with(an_instance_of(Gitlab::Metrics::RuntimeLimiter), cursor: 5)
          .and_call_original
      end

      worker.perform(project.id, 5)
    end

    it 'does not re-enqueue itself when the service completes' do
      expect(described_class).not_to receive(:perform_in)

      worker.perform(project.id)

      expect(merge_request.reload.head_pipeline).to eq(pipeline)
    end

    context 'when the service stops at the runtime limit' do
      before do
        allow_next_instance_of(Projects::ImportExport::LinkMergeRequestHeadPipelinesService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { completed: false, cursor: 42 }))
        end
      end

      it 're-enqueues itself from the returned cursor' do
        expect(described_class).to receive(:perform_in).with(described_class::RETRY_DELAY, project.id, 42)

        worker.perform(project.id)
      end
    end

    context 'when the project does not exist' do
      it 'does nothing' do
        expect(Projects::ImportExport::LinkMergeRequestHeadPipelinesService).not_to receive(:new)

        worker.perform(non_existing_record_id)
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [project.id] }

      it 'links the head pipeline' do
        perform_idempotent_work

        expect(merge_request.reload.head_pipeline).to eq(pipeline)
      end
    end
  end
end
