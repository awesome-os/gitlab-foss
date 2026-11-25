# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMergeProcessWorker, feature_category: :continuous_delivery do
  let(:merge_request) { create(:merge_request, :unique_branches) }

  # If the job inherits the link of a session and the merge user is the human of that session, the merge runs as
  # the service account. See https://gitlab.com/gitlab-org/gitlab/-/work_items/637329.
  describe 'composite identity of the enqueuing context', :request_store, :clean_gitlab_redis_queues_metadata do
    let_it_be(:service_account) { create(:user, :ai_service_account) }
    let_it_be(:user) { create(:user) }

    it 'opts out of the composite identity passthrough' do
      expect(described_class.skip_composite_identity_passthrough?).to be(true)
    end

    it 'does not give the link of a session to the job', :aggregate_failures do
      # The link that the CI job token of a session makes.
      ::Gitlab::Auth::Identity.link_from_scoped_user(service_account, user, context: :authentication)

      expect { described_class.perform_async({ 'pipeline_id' => non_existing_record_id }) }
        .to change { described_class.jobs.size }.by(1)
      expect(described_class.jobs.last).not_to have_key(::Gitlab::Auth::Identity::COMPOSITE_IDENTITY_SIDEKIQ_ARG)
    end
  end

  describe '#perform' do
    subject { described_class.new.perform(args) }

    let(:args) { { 'merge_request_id' => merge_request.id } }

    context 'when merge request is found' do
      it 'executes AutoMergeService' do
        expect_next_instance_of(AutoMergeService) do |auto_merge|
          expect(auto_merge).to receive(:process).with(merge_request)
        end

        subject
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:merge_request) { create(:merge_request, :merge_when_checks_pass) }
      let(:job_args) { [{ 'merge_request_id' => merge_request.id }] }
    end

    context 'when merge request is not found' do
      let(:args) { { 'merge_request_id' => -1 } }

      it 'does not execute AutoMergeService' do
        expect(AutoMergeService).not_to receive(:new)

        subject
      end
    end

    context 'when a pipeline is passed with auto mergeable MRs', :aggregate_failures do
      let(:merge_service) { instance_double(AutoMergeService, process: true) }
      let(:mwcp_merge_request) { create(:merge_request, :with_head_pipeline, :merge_when_checks_pass) }

      let(:args) do
        {
          'merge_request_id' => merge_request.id,
          'pipeline_id' => [mwcp_merge_request.head_pipeline.id]
        }
      end

      it 'initializes and executes AutoMergeService for the passed MR and those attached to the passed pipeline' do
        expect(AutoMergeService).to receive(:new).twice.and_return(merge_service)

        expect(merge_service).to receive(:process).with(merge_request)
        expect(merge_service).to receive(:process).with(mwcp_merge_request)

        subject
      end
    end

    context 'when pipeline is not found' do
      let(:args) { { 'pipeline_id' => -1 } }

      it 'does not execute AutoMergeService' do
        expect(AutoMergeService).not_to receive(:new)

        subject
      end
    end

    context 'when merge request id is nil' do
      let(:args) { { 'merge_request_id' => nil } }

      it 'does not execute AutoMergeService' do
        expect(AutoMergeService).not_to receive(:new)

        subject
      end
    end

    # Integer args are deprecated as of 17.5. IDs should be passed
    # as a hash with  merge_request_id and pipeline_id keys.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/497247
    context 'with integer args' do
      let(:args) { merge_request.id }

      context 'when merge request is found' do
        it 'executes AutoMergeService' do
          expect_next_instance_of(AutoMergeService) do |auto_merge|
            expect(auto_merge).to receive(:process)
          end

          subject
        end
      end

      context 'when merge request is not found' do
        let(:args) { -1 }

        it 'does not execute AutoMergeService' do
          expect(AutoMergeService).not_to receive(:new)

          subject
        end
      end

      context 'when merge request id is nil' do
        let(:args) { nil }

        it 'does not execute AutoMergeService' do
          expect(AutoMergeService).not_to receive(:new)

          subject
        end
      end
    end
  end
end
