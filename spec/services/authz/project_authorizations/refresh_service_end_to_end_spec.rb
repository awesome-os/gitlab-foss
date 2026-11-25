# frozen_string_literal: true

require 'spec_helper'

# Changes made the way production makes them, so the database triggers queue the events, then drained through the
# queue and compared with what Gitlab::ProjectAuthorizations calculates from scratch.
RSpec.describe Authz::ProjectAuthorizations::RefreshService, 'end to end', :aggregate_failures,
  feature_category: :permissions do
  let_it_be(:root) { create(:group) }
  let_it_be_with_reload(:subgroup) { create(:group, parent: root) }
  let_it_be(:invited) { create(:group) }
  let_it_be_with_reload(:other) { create(:group) }
  let_it_be_with_reload(:root_project) { create(:project, group: root) }
  let_it_be(:sub_project) { create(:project, group: subgroup) }
  let_it_be(:shared_project) { create(:project, group: other) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:invited_owner) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:newcomer) { create(:user) }

  let(:users) { [maintainer, invited_owner, reporter, newcomer] }
  let(:events) { Authz::ProjectAuthorizations::RefreshEvent }

  before_all do
    root.add_maintainer(maintainer)
    subgroup.add_reporter(reporter)
    invited.add_owner(invited_owner)
    create(:group_group_link, shared_group: subgroup, shared_with_group: invited,
      group_access: Gitlab::Access::DEVELOPER)
    create(:project_group_link, project: shared_project, group: invited, group_access: Gitlab::Access::REPORTER)
  end

  before do
    # The project producers are off, so only the queue writes for project changes.
    stub_feature_flags(authz_refresh_sidekiq_projects: false)

    # Start from an empty table, so every row below was written by the queue.
    ProjectAuthorization.delete_all
    events.delete_all
    events.enqueue(:user, users.map(&:id))
    drain
  end

  # Runs the queue to empty, including the events expansions and continued leases add, ignoring backoff.
  def drain
    10.times do
      break if events.status_pending.none?

      events.status_pending.update_all(visible_at: nil)
      described_class.new(Gitlab::Metrics::RuntimeLimiter.new(10.minutes)).execute
    end

    expect(events.status_pending).to be_empty
  end

  def stored(users)
    ProjectAuthorization.where(user: users).pluck(:user_id, :project_id, :access_level)
  end

  def expected(users)
    users.flat_map do |user|
      Gitlab::ProjectAuthorizations.new(user).calculate.map { |row| [user.id, row.project_id, row.access_level] }
    end
  end

  it 'repairs users from nothing' do
    expect(stored(users)).to match_array(expected(users))
    expect(stored([invited_owner])).to include([invited_owner.id, sub_project.id, Gitlab::Access::DEVELOPER],
      [invited_owner.id, shared_project.id, Gitlab::Access::REPORTER])
  end

  it 'follows memberships written in bulk, bypassing callbacks' do
    attributes = { source_id: subgroup.id, source_type: 'Namespace', type: 'GroupMember', notification_level: 3,
                   member_namespace_id: subgroup.id, access_level: Gitlab::Access::DEVELOPER }
    Member.insert_all([attributes.merge(user_id: newcomer.id)])
    GroupMember.where(user: maintainer, source: root).update_all(access_level: Gitlab::Access::GUEST)
    GroupMember.where(user: reporter).delete_all

    drain

    expect(stored(users)).to match_array(expected(users))
    expect(stored([reporter])).to be_empty
  end

  it 'follows a group share being granted' do
    create(:group_group_link, shared_group: other, shared_with_group: subgroup)

    drain

    expect(stored(users)).to match_array(expected(users))
    expect(stored([reporter]).map(&:second)).to include(shared_project.id)
  end

  it 'removes access through a deleted group share for every user' do
    GroupGroupLink.where(shared_group: subgroup).delete_all

    drain

    expect(stored(users)).to match_array(expected(users))
    expect(stored([invited_owner]).map(&:second)).not_to include(sub_project.id)
  end

  it 'follows a project share being removed' do
    ProjectGroupLink.where(project: shared_project).delete_all

    drain

    expect(stored(users)).to match_array(expected(users))
    expect(stored([invited_owner]).map(&:second)).not_to include(shared_project.id)
  end

  it 'follows a group moving to another parent' do
    Groups::TransferService.new(subgroup, create(:user, owner_of: [subgroup, other])).execute(other)

    drain

    expect(subgroup.reload.parent).to eq(other)
    expect(stored(users)).to match_array(expected(users))
    expect(stored([maintainer]).map(&:second)).not_to include(sub_project.id)
  end

  it 'follows the share lock' do
    other.update!(share_with_group_lock: true)

    drain

    expect(stored(users)).to match_array(expected(users))
    expect(stored([invited_owner]).map(&:second)).not_to include(shared_project.id)
  end

  it 'follows a project moving, and a project member added in bulk' do
    root_project.update!(namespace: other)
    ProjectMember.insert_all([{ source_id: root_project.id, source_type: 'Project', type: 'ProjectMember',
                                notification_level: 3, member_namespace_id: root_project.project_namespace_id,
                                access_level: Gitlab::Access::MAINTAINER, user_id: newcomer.id }])

    drain

    expect(stored(users)).to match_array(expected(users))
    expect(stored([newcomer])).to contain_exactly([newcomer.id, root_project.id, Gitlab::Access::MAINTAINER])
  end

  it 'gives access to a new project' do
    project = create(:project, group: subgroup)

    drain

    expect(stored(users)).to match_array(expected(users))
    expect(stored([reporter]).map(&:second)).to include(project.id)
  end

  it 'removes the access of a member who left just before the share was deleted' do
    GroupMember.where(user: invited_owner, source: invited).delete_all
    GroupGroupLink.where(shared_group: subgroup).delete_all

    drain

    expect(stored([invited_owner])).to be_empty
    expect(stored(users)).to match_array(expected(users))
  end

  it "doesn't skip a newly merged group's projects below a resumed run's cursor" do
    # A resumed run for the root group has written everything up to its cursor, the newest project.
    newest = create(:project, group: root)
    ProjectAuthorization.where(user: maintainer).delete_all
    root_reach = Authz::ProjectAuthorizations::Reach.new([root.id]).project_ids
    Authz::ProjectAuthorizations::RecalculateUserService.new(maintainer.id, project_ids: root_reach).execute
    events.delete_all
    create(:authz_refresh_event, target_type: :user_in_group, target_id: maintainer.id, scope_id: root.id,
      cursor: newest.id)

    # A new membership arrives, reaching a project older than that cursor.
    GroupMember.insert_all([{ source_id: other.id, source_type: 'Namespace', type: 'GroupMember',
                              notification_level: 3, member_namespace_id: other.id, user_id: maintainer.id,
                              access_level: Gitlab::Access::DEVELOPER }])
    expect(shared_project.id).to be < newest.id

    drain

    expect(stored([maintainer])).to include([maintainer.id, shared_project.id, Gitlab::Access::DEVELOPER])
    expect(stored([maintainer])).to match_array(expected([maintainer]))
  end

  it 'finishes a user whose recalculation runs out of time, over several leases' do
    stub_const('Authz::ProjectAuthorizations::RecalculateUserService::SLICE_SIZE', 1)
    allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap { |limiter| allow(limiter).to receive(:over_time?).and_return(true) }
    end
    ProjectAuthorization.where(user: invited_owner).delete_all
    events.enqueue(:user, [invited_owner.id])

    expect(Authz::ProjectAuthorizations::RecalculateUserService).to receive(:new).at_least(:twice).and_call_original

    drain

    expect(stored([invited_owner])).to match_array(expected([invited_owner]))
  end

  # Turning computing off again, as in a rollback, before the Sidekiq flag goes back on.
  it 'hands project changes made once computing is off to the old workers', :sidekiq_inline do
    stub_feature_flags(authz_refresh_compute_projects: false)
    ProjectMember.insert_all([{ source_id: root_project.id, source_type: 'Project', type: 'ProjectMember',
                                notification_level: 3, member_namespace_id: root_project.project_namespace_id,
                                access_level: Gitlab::Access::MAINTAINER, user_id: newcomer.id }])

    expect(AuthorizedProjectUpdate::ProjectRecalculatePerUserWorker).to receive(:perform_async)
      .with(root_project.id, newcomer.id).and_call_original

    drain

    expect(stored([newcomer])).to contain_exactly([newcomer.id, root_project.id, Gitlab::Access::MAINTAINER])
  end
end
