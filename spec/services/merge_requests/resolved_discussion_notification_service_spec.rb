# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ResolvedDiscussionNotificationService, feature_category: :code_review_workflow do
  let(:merge_request) { create(:merge_request) }
  let(:user) { create(:user) }
  let(:project) { merge_request.project }

  subject { described_class.new(project: project, current_user: user) }

  describe "#execute" do
    context "when not all discussions are resolved" do
      before do
        allow(merge_request).to receive(:discussions_resolved?).and_return(false)
      end

      it "doesn't add a system note" do
        expect(SystemNoteService).not_to receive(:resolve_all_discussions)

        subject.execute(merge_request)
      end

      it "doesn't send a notification email" do
        expect_any_instance_of(NotificationService).not_to receive(:resolve_all_discussions)

        subject.execute(merge_request)
      end

      it "doesn't send a webhook" do
        expect_any_instance_of(MergeRequests::BaseService).not_to receive(:execute_hooks)

        subject.execute(merge_request)
      end

      context 'when auto-merge is enabled' do
        let(:merge_request) { create(:merge_request, :merge_when_checks_pass) }

        it 'does not publish the discussions resolved event' do
          expect { subject.execute(merge_request) }.not_to publish_event(MergeRequests::DiscussionsResolvedEvent)
        end
      end
    end

    context "when all discussions are resolved" do
      before do
        allow(merge_request).to receive(:discussions_resolved?).and_return(true)
      end

      it "adds a system note" do
        expect(SystemNoteService).to receive(:resolve_all_discussions).with(merge_request, project, user)

        subject.execute(merge_request)
      end

      it "sends a notification email", :sidekiq_might_not_need_inline do
        expect_any_instance_of(NotificationService).to receive(:resolve_all_discussions).with(merge_request, user)

        subject.execute(merge_request)
      end

      context 'when send_notification flag is false' do
        it "does not send a notification email" do
          expect_any_instance_of(NotificationService).not_to receive(:resolve_all_discussions)

          subject.execute(merge_request, send_notifications: false)
        end
      end

      it "sends a webhook" do
        expect_any_instance_of(MergeRequests::BaseService).to receive(:execute_hooks).with(merge_request, 'update')

        subject.execute(merge_request)
      end

      it 'does not publish the discussions resolved event' do
        expect { subject.execute(merge_request) }.not_to publish_event(MergeRequests::DiscussionsResolvedEvent)
      end

      context 'when auto-merge is enabled' do
        let(:merge_request) { create(:merge_request, :merge_when_checks_pass) }

        it 'publishes the discussions resolved event' do
          expect { subject.execute(merge_request) }
            .to publish_event(MergeRequests::DiscussionsResolvedEvent)
            .with(current_user_id: user.id, merge_request_id: merge_request.id)
        end

        context 'when send_notification flag is false' do
          it 'publishes the discussions resolved event' do
            expect { subject.execute(merge_request, send_notifications: false) }
              .to publish_event(MergeRequests::DiscussionsResolvedEvent)
              .with(current_user_id: user.id, merge_request_id: merge_request.id)
          end
        end

        context 'when there is no current user' do
          let(:user) { nil }

          before do
            allow(SystemNoteService).to receive(:resolve_all_discussions)
          end

          it 'does not publish the discussions resolved event' do
            expect { subject.execute(merge_request) }.not_to publish_event(MergeRequests::DiscussionsResolvedEvent)
          end
        end
      end
    end
  end
end
