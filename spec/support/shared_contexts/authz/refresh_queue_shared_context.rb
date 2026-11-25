# frozen_string_literal: true

# Both groups' old Sidekiq refreshes are off, so only the refresh queue writes project_authorizations. Needs `users`,
# who each start with rows the queue wrote from nothing.
RSpec.shared_context 'with only the refresh queue writing project authorizations' do
  let(:refresh_events) { Authz::ProjectAuthorizations::RefreshEvent }

  before do
    stub_feature_flags(authz_refresh_sidekiq_projects: false, authz_refresh_sidekiq_memberships: false)

    ProjectAuthorization.delete_all
    refresh_events.delete_all
    refresh_events.enqueue(:user, users.map(&:id))
    drain_refresh_queue
    Sidekiq::Worker.clear_all
  end

  # Specs run some refreshes inline through StubbedMember, so this checks both that none is queued and none runs.
  def sidekiq_refresh_workers
    [
      AuthorizedProjectsWorker,
      AuthorizedProjectUpdate::ProjectRecalculateWorker,
      AuthorizedProjectUpdate::ProjectRecalculatePerUserWorker,
      AuthorizedProjectUpdate::UserRefreshWithLowUrgencyWorker,
      AuthorizedProjectUpdate::UserRefreshFromReplicaWorker,
      AuthorizedProjectUpdate::EnqueueGroupMembersRefreshAuthorizedProjectsWorker
    ]
  end

  # Makes the change, checks it left no old refresh to Sidekiq, drains the queue and checks every user's rows.
  def refresh_through_queue
    sidekiq_refresh_workers.each { |worker| expect(worker).not_to receive(:new) }

    yield

    expect(sidekiq_refresh_workers.flat_map(&:jobs)).to be_empty
    drain_refresh_queue
    expect(stored_authorizations(users)).to match_array(expected_authorizations(users))
  end

  # Runs the queue to empty, including the events expansions and continued leases add, ignoring backoff.
  def drain_refresh_queue
    10.times do
      break if refresh_events.status_pending.none?

      refresh_events.status_pending.update_all(visible_at: nil)
      Authz::ProjectAuthorizations::RefreshService.new(Gitlab::Metrics::RuntimeLimiter.new(10.minutes)).execute
    end

    expect(refresh_events.status_pending).to be_empty
  end

  def stored_authorizations(users)
    ProjectAuthorization.where(user: users).pluck(:user_id, :project_id, :access_level)
  end

  def expected_authorizations(users)
    users.flat_map do |user|
      Gitlab::ProjectAuthorizations.new(user).calculate.map { |row| [user.id, row.project_id, row.access_level] }
    end
  end

  def project_ids_of(user)
    ProjectAuthorization.where(user: user).pluck(:project_id)
  end
end
