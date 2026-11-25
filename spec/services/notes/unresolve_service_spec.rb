# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::UnresolveService, feature_category: :code_review_workflow do
  # refind: the webhook payload example mutates the project, which let_it_be freezes.
  let_it_be(:merge_request, refind: true) { create(:merge_request) }
  let_it_be(:user) { merge_request.author }

  let(:note) { create(:diff_note_on_merge_request, noteable: merge_request, project: merge_request.project) }
  let(:service) { described_class.new(merge_request.project, user) }

  before do
    note.resolve!(user)
  end

  describe '#execute' do
    it 'unresolves the note' do
      service.execute(note)

      note.reload

      expect(note.resolved?).to be false
      expect(note.resolved_by).to be_nil
    end

    context 'when the user is throttled' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:discussions_resolve, hash_including(scope: { user: user })).and_return(true)
      end

      it 'raises an error without unresolving the note' do
        expect { service.execute(note) }.to raise_error(RateLimitedService::RateLimitedError)
        expect(note.reload).to be_resolved
      end
    end

    context 'when noteable is not a MergeRequest' do
      let(:note) { create(:note_on_issue, project: merge_request.project) }

      it 'does not send a merge request webhook' do
        expect(MergeRequests::UnresolvedDiscussionNotificationService).not_to receive(:new)

        service.execute(note)
      end
    end

    context 'when noteable is a MergeRequest' do
      # The service reads `discussions_resolved?` before unresolving, which memoizes
      # `resolvable_discussions` on the noteable. Guards against that memoization leaking
      # into the payload, which is built from the same object after the note is unresolved.
      it 'reports the blocking discussions as unresolved in the webhook payload' do
        hook_target = note.noteable.project
        hook_target.update!(only_allow_merge_if_all_discussions_are_resolved: true)

        blocking_discussions_resolved = :never_called
        allow(hook_target).to receive(:execute_hooks) do |payload, _scope|
          blocking_discussions_resolved = payload[:object_attributes][:blocking_discussions_resolved]
        end

        described_class.new(hook_target, user).execute(note)

        expect(blocking_discussions_resolved).to be(false)
      end

      it 'sends a merge request webhook' do
        expect_next_instance_of(MergeRequests::UnresolvedDiscussionNotificationService) do |instance|
          expect(instance).to receive(:execute)
            .with(merge_request, all_discussions_resolved_before: true)
        end

        service.execute(note)
      end

      context 'when there are existing unresolved threads' do
        before do
          create(:diff_note_on_merge_request, noteable: merge_request, project: merge_request.project)
        end

        it 'reports that the threads were not all resolved beforehand' do
          expect_next_instance_of(MergeRequests::UnresolvedDiscussionNotificationService) do |instance|
            expect(instance).to receive(:execute)
              .with(merge_request, all_discussions_resolved_before: false)
          end

          service.execute(note)
        end
      end

      it "does not scale the query count with the number of other resolvable notes" do
        control = ActiveRecord::QueryRecorder.new { described_class.new(merge_request.project, user).execute(note) }

        note.resolve!(user)
        other_notes = create_list(
          :diff_note_on_merge_request,
          10,
          noteable: merge_request,
          project: merge_request.project
        )
        other_notes.each { |other_note| other_note.discussion.resolve!(user) }

        expect { described_class.new(merge_request.project, user).execute(note) }
          .not_to exceed_query_limit(control)
      end
    end
  end
end
