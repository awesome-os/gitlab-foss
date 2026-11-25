# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::TransferService, :sidekiq_inline, feature_category: :groups_and_projects do
  let_it_be_with_reload(:user) { create(:user) }

  let(:transfer_service) { described_class.new(group, user) }

  describe '#schedule_async_transfer' do
    let_it_be(:current_parent_group) { create(:group) }
    let_it_be_with_reload(:new_parent_group) { create(:group, :public, owners: user) }

    let_it_be_with_reload(:group) { create(:group, :public, parent: current_parent_group, owners: user) }

    subject(:schedule) { transfer_service.schedule_async_transfer(new_parent_group) }

    it 'returns success response and enqueues the worker', :aggregate_failures do
      expect(Namespaces::Groups::TransferWorker).to receive(:perform_async).with(
        group.id,
        new_parent_group.id,
        user.id
      )

      expect(schedule).to be_success
      expect(schedule.message).to eq('Group transfer is scheduled. If it fails, you get a to-do item with the reason.')
    end

    it 'transitions the group to transfer_scheduled' do
      allow(Namespaces::Groups::TransferWorker).to receive(:perform_async)

      schedule

      expect(group.reload.state).to eq('transfer_scheduled')
    end

    it 'stores transfer_target_parent_id in state_metadata', :aggregate_failures do
      allow(Namespaces::Groups::TransferWorker).to receive(:perform_async)

      schedule

      metadata = group.reload.state_metadata
      expect(metadata['transfer_target_parent_id']).to eq(new_parent_group.id)
      expect(metadata['transfer_scheduled_by_user_id']).to eq(user.id)
      expect(metadata['transfer_scheduled_at']).to be_present
    end

    context 'when transferring to root (nil parent)' do
      subject(:schedule) { transfer_service.schedule_async_transfer(nil) }

      it 'enqueues the worker with nil new_parent_group_id', :aggregate_failures do
        expect(Namespaces::Groups::TransferWorker).to receive(:perform_async).with(
          group.id,
          nil,
          user.id
        )

        expect(schedule).to be_success
        expect(schedule.message)
          .to eq('Group transfer is scheduled. If it fails, you get a to-do item with the reason.')
      end

      it 'stores nil transfer_target_parent_id' do
        allow(Namespaces::Groups::TransferWorker).to receive(:perform_async)

        schedule

        expect(group.reload.state_metadata['transfer_target_parent_id']).to be_nil
      end
    end

    context 'when the state transition fails' do
      before do
        group.update_column(:state, Group.states[:creation_in_progress])
      end

      it 'returns error response and does not enqueue the worker', :aggregate_failures do
        expect(Namespaces::Groups::TransferWorker).not_to receive(:perform_async)

        expect(schedule).to be_error
        expect(schedule.message).to eq(
          'Unable to initiate transfer. The group may already have a transfer in progress.'
        )
      end
    end

    context 'when group has stale transfer state with no active worker' do
      before do
        group.schedule_transfer!(transition_user: user)
        group.start_transfer!(transition_user: user)
      end

      it 'cancels the stale state and proceeds with the transfer', :aggregate_failures do
        allow(Namespaces::Groups::TransferWorker).to receive(:perform_async)

        expect(schedule).to be_success
        expect(group.reload.state).to eq('transfer_scheduled')
      end

      it 'logs a warning about the stale state' do
        allow(Namespaces::Groups::TransferWorker).to receive(:perform_async)
        allow(Gitlab::AppLogger).to receive(:warn)

        schedule

        expect(Gitlab::AppLogger).to have_received(:warn).with(hash_including(
          'message' => 'Cancelling stale transfer state - no active worker lease found',
          'group_id' => group.id,
          'gl_namespace_id' => group.id,
          'namespace_type' => 'group',
          'correlation_id' => kind_of(String)
        ))
      end
    end

    context 'when group has stale transfer_scheduled state with no active worker' do
      before do
        group.schedule_transfer!(transition_user: user)
      end

      it 'cancels the stale state and proceeds with the transfer', :aggregate_failures do
        allow(Namespaces::Groups::TransferWorker).to receive(:perform_async)

        expect(schedule).to be_success
        expect(group.reload.state).to eq('transfer_scheduled')
      end
    end

    context 'when group has transfer state with active worker lease' do
      before do
        group.schedule_transfer!(transition_user: user)
        group.start_transfer!(transition_user: user)
        Gitlab::ExclusiveLease.new(
          Namespaces::Groups::TransferWorker.lease_key(group.id), timeout: 30.minutes
        ).try_obtain
      end

      it 'does not cancel the state and returns error', :aggregate_failures do
        expect(Namespaces::Groups::TransferWorker).not_to receive(:perform_async)

        expect(schedule).to be_error
        expect(schedule.message).to eq(
          'Unable to initiate transfer. The group may already have a transfer in progress.'
        )
      end
    end
  end
end
