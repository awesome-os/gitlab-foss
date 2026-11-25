# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::TransferService, :sidekiq_inline, feature_category: :groups_and_projects do
  let_it_be_with_reload(:user) { create(:user) }

  let(:transfer_service) { described_class.new(group, user) }

  context 'when transferring labels' do
    let(:new_parent_group) { create(:group, :private, owners: user) }
    let(:parent_group) { create(:group, owners: user) }
    let(:group) { create(:group, parent: parent_group) }
    let(:project) { create(:project, group: group) }

    it 'delegates transfer to Labels::TransferService' do
      expect_next_instance_of(Labels::TransferService, user, project.group, project) do |labels_transfer_service|
        expect(labels_transfer_service).to receive(:execute).once.and_call_original
      end

      transfer_service.execute(new_parent_group)
    end
  end

  context 'when disabling merge request collaboration on access reduction' do
    let(:group) { create(:group, :public, owners: user) }
    let!(:project) { create(:project, :public, group: group) }

    context 'when the new parent group is private' do
      let_it_be(:new_parent_group, freeze: false) { create(:group, :private, owners: user) }

      it 'enqueues the worker for the affected projects' do
        expect(::MergeRequests::DisableCollaborationOnUnauthorizedWorker)
          .to receive(:bulk_perform_async).with([[project.id]])

        transfer_service.execute(new_parent_group)
      end

      context 'when no project visibility is reduced' do
        let(:group) { create(:group, :private, owners: user) }
        let!(:project) { create(:project, :private, group: group) }

        it 'does not enqueue the worker' do
          expect(::MergeRequests::DisableCollaborationOnUnauthorizedWorker)
            .not_to receive(:bulk_perform_async)

          transfer_service.execute(new_parent_group)
        end
      end
    end

    context 'when the new parent group is internal' do
      let_it_be(:new_parent_group, freeze: false) { create(:group, :internal, owners: user) }

      it 'does not enqueue the worker' do
        expect(::MergeRequests::DisableCollaborationOnUnauthorizedWorker)
          .not_to receive(:bulk_perform_async)

        transfer_service.execute(new_parent_group)
      end
    end

    context 'when transferring to a root group' do
      let(:group) { create(:group, :public, :nested, owners: user) }

      it 'does not enqueue the worker' do
        expect(::MergeRequests::DisableCollaborationOnUnauthorizedWorker)
          .not_to receive(:bulk_perform_async)

        transfer_service.execute(nil)
      end
    end
  end

  describe '#execute' do
    context 'when transfer succeeds' do
      let_it_be_with_reload(:group) { create(:group, :nested, owners: user) }
      let_it_be(:target) { create(:group, owners: user) }

      it 'sends transfer notification email with the old path' do
        old_path = group.full_path

        expect_next_instance_of(NotificationService) do |notification|
          expect(notification).to receive(:group_was_transferred).with(group, old_path)
        end

        transfer_service.execute(target)
      end

      it 'records a success transfer metric and duration' do
        expect(::Gitlab::Metrics::Transfers).to receive(:count_transfer)
          .with(namespace_type: 'group', result: 'success')
        expect(::Gitlab::Metrics::Transfers).to receive(:observe_transfer_duration)
          .with(duration_s: kind_of(Numeric), namespace_type: 'group')

        transfer_service.execute(target)
      end

      it 'creates a transferred activity event' do
        expect { transfer_service.execute(target) }.to change {
          Event.transferred_action.where(group: group, project: nil).count
        }.by(1)
      end

      it 'does not send notification when transfer fails' do
        expect(NotificationService).not_to receive(:new)

        transfer_service.execute(group.parent)
      end
    end

    context 'with namespace_commit_emails concerns' do
      let_it_be_with_reload(:group) { create(:group, owners: user) }
      let_it_be(:target) { create(:group, owners: user) }

      context 'when origin is a root group' do
        before do
          create_list(:namespace_commit_email, 2, namespace: group)
        end

        it 'deletes all namespace_commit_emails' do
          expect { transfer_service.execute(target) }
            .to change { group.namespace_commit_emails.count }.by(-2)
        end

        it_behaves_like 'publishes a GroupTransferedEvent'
      end

      context 'when origin is not a root group' do
        let(:group) { create(:group, parent: create(:group), owners: user) }

        it 'does not attempt to delete namespace_commit_emails' do
          expect(Users::NamespaceCommitEmail).not_to receive(:delete_for_namespace)

          transfer_service.execute(target)
        end
      end
    end
  end

  describe 'lock retries in proceed_to_transfer' do
    let_it_be_with_reload(:group) { create(:group, :public, :nested, owners: user) }
    let_it_be(:target) { create(:group, owners: user) }

    it 'uses WithLockRetries for the transaction' do
      expect_next_instance_of(Gitlab::Database::WithLockRetries) do |retries|
        expect(retries).to receive(:run).with(raise_on_exhaustion: true).and_call_original
      end

      transfer_service.execute(target)
    end

    it 'raises AttemptsExhaustedError when lock retries are exhausted' do
      lock_retries = instance_double(Gitlab::Database::WithLockRetries)
      allow(Gitlab::Database::WithLockRetries).to receive(:new).and_return(lock_retries)
      allow(lock_retries).to receive(:run)
        .and_raise(Gitlab::Database::WithLockRetries::AttemptsExhaustedError)

      expect { transfer_service.execute(target) }
        .to raise_error(Gitlab::Database::WithLockRetries::AttemptsExhaustedError)
    end
  end
end
