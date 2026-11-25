# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssueEmailParticipants::CreateService, feature_category: :service_desk do
  shared_examples 'a successful service execution' do
    it 'creates new participants', :aggregate_failures do
      metric_transaction = instance_double(Gitlab::Metrics::WebTransaction, increment: true, observe: true)
      allow(::Gitlab::Metrics::BackgroundTransaction).to receive(:current).and_return(metric_transaction)
      expect(metric_transaction).to receive(:add_event).with(:service_desk_new_participant_email)
        .exactly(expected_emails.size).times

      expect(Notify).to receive(:service_desk_new_participant_email).exactly(expected_emails.size).times
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_later: true))

      response = service.execute
      expect(response).to be_success

      issue.reset
      note = issue.notes.last
      expect(note.system?).to be true
      expect(note.author).to eq(user)
      expect(note.system_note_metadata.action).to eq('issue_email_participants')

      participants_emails = issue.email_participants_emails_downcase

      expected_emails.each do |email|
        expect(participants_emails).to include(email)
        expect(response.message).to include(email)
        expect(note.note).to include(email)
      end
    end
  end

  shared_examples 'a failed service execution' do
    it 'returns error ServiceResponse with message', :aggregate_failures do
      response = service.execute
      expect(response).to be_error
      expect(response.message).to eq(error_message)
    end
  end

  describe '#execute' do
    let_it_be_with_reload(:project) { create(:project, skip_disk_validation: true) }
    let_it_be_with_reload(:issue) { create(:issue, project: project) }
    let_it_be(:user) { create(:user) }
    let(:emails) { nil }
    let(:service) { described_class.new(target: issue, current_user: user, emails: emails) }
    let(:expected_emails) { emails }
    let(:error_underprivileged) { _("You don't have permission to manage email participants.") }
    let(:error_no_participants_added) do
      _("No email participants were added. Either none were provided, or they already exist.")
    end

    context 'when the user is not a project member' do
      let(:error_message) { error_underprivileged }

      it_behaves_like 'a failed service execution'
    end

    context 'when user has reporter role in project' do
      before_all do
        project.add_reporter(user)
      end

      context 'when no emails are provided' do
        let(:error_message) { error_no_participants_added }

        it_behaves_like 'a failed service execution'
      end

      context 'when one email is provided' do
        let(:emails) { ['user@example.com'] }

        it_behaves_like 'a successful service execution'

        context 'when email is already a participant of the issue' do
          let(:error_message) { error_no_participants_added }

          before do
            issue.issue_email_participants.create!(email: emails.first)
          end

          it_behaves_like 'a failed service execution'

          context 'when email is formatted in a different case' do
            let(:emails) { ['USER@example.com'] }

            it_behaves_like 'a failed service execution'
          end
        end

        context 'when participants limit on issue is reached' do
          before do
            stub_const("#{described_class}::MAX_NUMBER_OF_RECORDS", 1)
            issue.issue_email_participants.create!(email: 'existing@example.com')
          end

          let(:error_message) { error_no_participants_added }

          it_behaves_like 'a failed service execution'

          it 'logs count of emails above limit' do
            expect(Gitlab::AppLogger).to receive(:info).with({ above_limit_count: 1 }).once
            service.execute
          end
        end
      end

      context 'when multiple emails are provided' do
        let(:emails) { ['user@example.com', 'other-user@example.com'] }

        it_behaves_like 'a successful service execution'

        it 'checks uniqueness in the database once per new participant' do
          recorder = ActiveRecord::QueryRecorder.new { service.execute }
          uniqueness_queries = recorder.log.grep(/SELECT 1 AS one FROM "issue_email_participants"/)

          expect(uniqueness_queries.size).to eq(emails.size)
        end

        context 'when duplicate email provided' do
          let(:emails) { ['user@example.com', 'user@example.com'] }
          let(:expected_emails) { emails[...-1] }

          it_behaves_like 'a successful service execution'
        end

        context 'when the same email is provided in different cases' do
          let(:emails) { ['user@example.com', 'USER@example.com'] }
          let(:expected_emails) { emails[...-1] }

          it_behaves_like 'a successful service execution'
        end

        context 'when an email is already a participant of the issue' do
          let(:expected_emails) { emails[1...] }

          before do
            issue.issue_email_participants.create!(email: emails.first)
          end

          it_behaves_like 'a successful service execution'

          it 'does not check it against the daily limit for new email participants' do
            expect_next_instance_of(::ServiceDesk::ExternalParticipantLimiter) do |limiter|
              expect(limiter).to receive(:allow?).once.with('other-user@example.com').and_return(true)
            end

            service.execute
          end
        end

        context 'when only some emails can be added because of participants limit' do
          before do
            stub_const("#{described_class}::MAX_NUMBER_OF_RECORDS", 1)
          end

          let(:expected_emails) { emails[...-1] }

          it_behaves_like 'a successful service execution'

          it 'logs count of emails above limit' do
            expect(Gitlab::AppLogger).to receive(:info).with({ above_limit_count: 1 }).once
            service.execute
          end
        end
      end

      context 'when more than the allowed number of emails are provided' do
        let(:emails) { (1..7).map { |i| "user#{i}@example.com" } }

        let(:expected_emails) { emails[...-1] }

        it_behaves_like 'a successful service execution'
      end

      context 'when the namespace is over the Service Desk email rate limit' do
        let(:emails) { ['user@example.com', 'other-user@example.com'] }

        before do
          allow_next_instance_of(::ServiceDesk::EmailRateLimiter) do |limiter|
            allow(limiter).to receive(:rate_limit_batch!).and_return(true)
            allow(limiter).to receive(:post_suppression_notice)
          end
        end

        it 'still creates the participant records but skips the emails' do
          expect(Notify).not_to receive(:service_desk_new_participant_email)

          response = service.execute

          expect(response).to be_success
          expect(issue.reset.email_participants_emails_downcase).to match_array(emails)
        end

        it 'posts one suppression notice' do
          posted_target = nil

          allow_next_instance_of(::ServiceDesk::EmailRateLimiter) do |limiter|
            allow(limiter).to receive(:rate_limit_batch!).and_return(true)
            allow(limiter).to receive(:post_suppression_notice) { |target| posted_target = target }
          end

          service.execute

          expect(posted_target).to eq(issue)
        end

        # Another request can add the same emails after the checks and before
        # the create, so the uniqueness validation rejects them here.
        context 'when another request adds the emails first' do
          before do
            allow_next_instance_of(::ServiceDesk::ExternalParticipantLimiter) do |limiter|
              allow(limiter).to receive(:allow?) do |email|
                IssueEmailParticipant.create!(issue: issue, email: email)
                true
              end
            end
          end

          it 'adds nothing and posts no suppression notice', :aggregate_failures do
            expect_next_instance_of(::ServiceDesk::EmailRateLimiter) do |limiter|
              expect(limiter).to receive(:rate_limit_batch!).and_return(true)
              expect(limiter).not_to receive(:post_suppression_notice)
            end

            response = service.execute

            expect(response).to be_error
            expect(response.message).to eq(error_no_participants_added)
          end
        end
      end

      context 'when the namespace is not over the Service Desk email rate limit' do
        let(:emails) { ['user@example.com'] }

        it_behaves_like 'a successful service execution'
      end

      context 'when the namespace reached its daily limit for new email participants' do
        let(:emails) { ['user@example.com', 'other-user@example.com'] }
        let(:expected_emails) { ['user@example.com'] }

        before do
          allow_next_instance_of(::ServiceDesk::ExternalParticipantLimiter) do |limiter|
            allow(limiter).to receive(:allow?) { |email| email == 'user@example.com' }
          end
        end

        it_behaves_like 'a successful service execution'

        it 'reports the emails it did not add', :aggregate_failures do
          response = service.execute

          expect(response.message).to eq(
            "Added user@example.com. Couldn't add other-user@example.com because the namespace reached " \
              "its daily limit for new email participants. Try again later."
          )
          expect(response.payload).to eq(limited_emails: ['other-user@example.com'])
          expect(issue.reset.email_participants_emails_downcase).to eq(['user@example.com'])
        end

        it 'charges the email rate limiter only for the participants it adds' do
          expect_next_instance_of(::ServiceDesk::EmailRateLimiter) do |limiter|
            expect(limiter).to receive(:rate_limit_batch!).with(1).and_return(false)
          end

          service.execute
        end

        context 'when no email is within the limit' do
          before do
            allow_next_instance_of(::ServiceDesk::ExternalParticipantLimiter) do |limiter|
              allow(limiter).to receive(:allow?).and_return(false)
            end
          end

          it 'adds no participants and returns an error', :aggregate_failures do
            expect(::ServiceDesk::EmailRateLimiter).not_to receive(:new)

            response = service.execute

            expect(response).to be_error
            expect(response.reason).to eq(:participant_limit_reached)
            expect(response.message).to eq(
              "Couldn't add user@example.com and other-user@example.com because the namespace reached " \
                "its daily limit for new email participants. Try again later."
            )
            expect(response.payload).to eq(limited_emails: emails)
            expect(issue.reset.issue_email_participants).to be_empty
            expect(issue.notes).to be_empty
          end
        end
      end

      context 'when checking emails against the daily limit for new email participants' do
        let(:emails) { ['not-an-email', 'user@example.com', 'other-user@example.com'] }

        before do
          stub_const("#{described_class}::MAX_NUMBER_OF_RECORDS", 1)
        end

        it 'checks only valid emails that fit in the remaining slots' do
          expect_next_instance_of(::ServiceDesk::ExternalParticipantLimiter) do |limiter|
            expect(limiter).to receive(:allow?).once.with('user@example.com').and_return(true)
          end

          service.execute
        end
      end

      context 'when emails_to_add exceeds the remaining participant slots' do
        let(:emails) { (1..7).map { |i| "user#{i}@example.com" } }

        before do
          stub_const("#{described_class}::MAX_NUMBER_OF_RECORDS", 3)
        end

        it 'charges the limiter with the clamped count, not the requested count' do
          expect_next_instance_of(::ServiceDesk::EmailRateLimiter) do |limiter|
            expect(limiter).to receive(:rate_limit_batch!).with(3).and_return(false)
          end

          service.execute
        end
      end
    end
  end
end
