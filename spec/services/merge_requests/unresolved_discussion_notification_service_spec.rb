# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::UnresolvedDiscussionNotificationService, feature_category: :code_review_workflow do
  let(:merge_request) { create(:merge_request) }
  let(:user) { create(:user) }
  let(:project) { merge_request.project }

  subject(:service) { described_class.new(project: project, current_user: user) }

  describe '#execute' do
    context 'when the merge request already had unresolved threads' do
      it 'does not send a webhook' do
        expect(project).not_to receive(:execute_hooks)

        service.execute(merge_request, all_discussions_resolved_before: false)
      end
    end

    context 'when the merge request previously had all threads resolved' do
      it 'sends a merge request webhook' do
        expect(project).to receive(:execute_hooks).with(anything, :merge_request_hooks)

        service.execute(merge_request, all_discussions_resolved_before: true)
      end

      it 'reports the blocking discussions as unresolved in the payload' do
        project.update!(only_allow_merge_if_all_discussions_are_resolved: true)
        create(:diff_note_on_merge_request, noteable: merge_request, project: project)

        expect(project).to receive(:execute_hooks) do |payload, _scope|
          expect(payload[:object_attributes][:blocking_discussions_resolved]).to be(false)
        end

        service.execute(merge_request, all_discussions_resolved_before: true)
      end

      it 'does not build the payload from a stale unresolved_notes cache' do
        project.update!(only_allow_merge_if_all_discussions_are_resolved: true)

        # The cache is populated while every thread is resolved, then a thread is reopened.
        merge_request.unresolved_notes.load
        create(:diff_note_on_merge_request, noteable: merge_request, project: project)

        expect(project).to receive(:execute_hooks) do |payload, _scope|
          expect(payload[:object_attributes][:blocking_discussions_resolved]).to be(false)
        end

        service.execute(merge_request, all_discussions_resolved_before: true)
      end
    end
  end
end
