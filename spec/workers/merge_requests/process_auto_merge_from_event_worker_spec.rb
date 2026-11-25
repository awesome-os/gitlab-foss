# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ProcessAutoMergeFromEventWorker, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, merge_user: user) }
  let(:merge_request_id) { merge_request.id }

  let(:data) { { current_user_id: user.id, merge_request_id: merge_request_id, approved_at: Time.current.iso8601 } }

  it_behaves_like 'process auto merge from event worker' do
    let(:event) { ::MergeRequests::DiscussionsResolvedEvent.new(data: data) }
  end

  it_behaves_like 'process auto merge from event worker' do
    let(:event) { ::MergeRequests::DraftStateChangeEvent.new(data: data) }
  end

  it_behaves_like 'process auto merge from event worker' do
    let(:data) { { merge_request_id: merge_request_id, project_id: project.id } }
    let(:event) { ::MergeRequests::PipelineCreationCompletedEvent.new(data: data) }

    before do
      merge_request.update!(auto_merge_enabled: true)
    end
  end

  context 'with a CloudEvent' do
    let_it_be_with_reload(:auto_merge_request) do
      create(:merge_request, :merge_when_checks_pass,
        source_project: project, source_branch: 'cloud-event', merge_user: user)
    end

    let(:approval) { build(:approval, merge_request: auto_merge_request, user: user, created_at: Time.current) }
    let(:event) do
      ::MergeRequests::ApprovedCloudEvent.build(
        merge_request: auto_merge_request, current_user: user, approval: approval
      )
    end

    it 'processes the merge request from the event payload' do
      expect_next_instance_of(AutoMergeService, project, user) do |service|
        expect(service).to receive(:process).with(auto_merge_request)
      end

      consume_event(subscriber: described_class, event: event)
    end

    describe '.dispatch?' do
      it 'is true when auto-merge is enabled' do
        expect(described_class.dispatch?(event)).to be(true)
      end

      it 'is false when auto-merge is not enabled' do
        auto_merge_request.update_column(:auto_merge_enabled, false)

        expect(described_class.dispatch?(event)).to be(false)
      end
    end
  end

  # If the job inherits the link of a session and the merge user is the human of that session, the merge runs as
  # the service account. See https://gitlab.com/gitlab-org/gitlab/-/work_items/637329.
  describe 'composite identity of the enqueuing context', :request_store do
    let_it_be(:service_account) { create(:user, :ai_service_account) }

    let(:event) do
      ::MergeRequests::DiscussionsResolvedEvent.new(
        data: { current_user_id: service_account.id, merge_request_id: merge_request.id }
      )
    end

    it 'opts out of the composite identity passthrough' do
      expect(described_class.skip_composite_identity_passthrough?).to be(true)
    end

    it 'does not give the link of a session to the job of an event that the session causes', :aggregate_failures do
      # The link that the OAuth token of a session makes.
      ::Gitlab::Auth::Identity.link_from_scoped_user(service_account, user, context: :authentication)

      expect { ::Gitlab::EventStore.publish(event) }.to change { described_class.jobs.size }.by(1)
      expect(described_class.jobs.last).not_to have_key(::Gitlab::Auth::Identity::COMPOSITE_IDENTITY_SIDEKIQ_ARG)
    end
  end

  describe 'PipelineCreationCompletedEvent subscription' do
    let_it_be_with_reload(:auto_merge_request) do
      create(:merge_request, :merge_when_checks_pass,
        source_project: project, source_branch: 'auto-merge', merge_user: user)
    end

    let(:pipeline_id) { nil }
    let(:event) do
      ::MergeRequests::PipelineCreationCompletedEvent.new(
        data: { merge_request_id: auto_merge_request.id, project_id: project.id, pipeline_id: pipeline_id }.compact
      )
    end

    it_behaves_like 'subscribes to event'

    it 'checks for the merge request on the primary' do
      lb_session = ::Gitlab::Database::LoadBalancing::SessionMap.current(MergeRequest.load_balancer)
      allow(::Gitlab::Database::LoadBalancing::SessionMap).to receive(:current).and_call_original
      allow(::Gitlab::Database::LoadBalancing::SessionMap)
        .to receive(:current).with(MergeRequest.load_balancer).and_return(lb_session)
      expect(lb_session).to receive(:use_primary).and_call_original

      ::Gitlab::EventStore.publish(event)
    end

    context 'when a pipeline was created' do
      let(:pipeline_id) { non_existing_record_id }

      it_behaves_like 'ignores the published event'
    end

    context 'when the merge request is closed' do
      before do
        auto_merge_request.update_column(:state_id, MergeRequest.available_states[:closed])
      end

      it_behaves_like 'ignores the published event'
    end

    context 'when auto-merge is not enabled' do
      before do
        auto_merge_request.update_column(:auto_merge_enabled, false)
      end

      it_behaves_like 'ignores the published event'
    end
  end
end
