# frozen_string_literal: true

# Needs refresh_action, and queued_refresh_event: the attributes of the event the change's trigger queues, or nil.
# skipped_user_refresh_ids, if given, lists the user ID arguments of skipped UserProjectAccessChangedService calls.
RSpec.shared_examples 'leaves the project refresh to the refresh queue' do
  it 'queues no Sidekiq refresh once the refresh queue replaces it, only the refresh event' do
    stub_feature_flags(authz_refresh_sidekiq_projects: false)

    expect(AuthorizedProjectUpdate::ProjectRecalculateWorker).not_to receive(:perform_async)
    expect(AuthorizedProjectUpdate::ProjectRecalculateWorker).not_to receive(:bulk_perform_async)
    expect(AuthorizedProjectUpdate::ProjectRecalculatePerUserWorker).not_to receive(:perform_async)
    # Specs run the per-user worker inline for project members, through StubbedMember.
    expect(AuthorizedProjectUpdate::ProjectRecalculatePerUserWorker).not_to receive(:new)
    expect(AuthorizedProjectUpdate::EnqueueGroupMembersRefreshAuthorizedProjectsWorker).not_to receive(:perform_async)

    if respond_to?(:skipped_user_refresh_ids)
      Array.wrap(skipped_user_refresh_ids).each do |ids|
        expect(UserProjectAccessChangedService).not_to receive(:new).with(ids)
      end
    end

    # Setup queues events through the same triggers, so only the action's own count.
    Authz::ProjectAuthorizations::RefreshEvent.delete_all

    refresh_action

    if queued_refresh_event
      expect(Authz::ProjectAuthorizations::RefreshEvent.status_pending.where(queued_refresh_event)).to exist
    end
  end
end

# Needs refresh_action, and queued_refresh_event: the attributes of the event the change's trigger queues.
RSpec.shared_examples 'leaves the membership refresh to the refresh queue' do
  it 'queues no Sidekiq refresh once the refresh queue replaces it, only the refresh event' do
    stub_feature_flags(authz_refresh_sidekiq_memberships: false)

    expect(AuthorizedProjectsWorker).not_to receive(:bulk_perform_async)
    expect(AuthorizedProjectUpdate::UserRefreshWithLowUrgencyWorker).not_to receive(:bulk_perform_async)
    expect(AuthorizedProjectUpdate::UserRefreshFromReplicaWorker).not_to receive(:bulk_perform_in)
    expect(AuthorizedProjectUpdate::EnqueueGroupMembersRefreshAuthorizedProjectsWorker).not_to receive(:perform_async)

    # Setup queues events through the same triggers, so only the action's own count.
    Authz::ProjectAuthorizations::RefreshEvent.delete_all

    refresh_action

    expect(Authz::ProjectAuthorizations::RefreshEvent.status_pending.where(queued_refresh_event)).to exist
  end
end
