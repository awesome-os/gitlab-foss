# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::ProjectAuthorizations::RecalculateUserService, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project, group: other_group) }

  before_all do
    group.add_developer(user)
    other_group.add_developer(user)
  end

  def levels
    ProjectAuthorization.where(user: user).pluck(:project_id, :access_level)
  end

  def add_row(project_id, access_level)
    ProjectAuthorization.insert_all([{ user_id: user.id, project_id: project_id, access_level: access_level,
                                       is_unique: true }])
  end

  context 'with groups' do
    subject(:execute) { described_class.new(user.id, group_ids: [group.id]).execute }

    it "only recalculates the groups' reach" do
      ProjectAuthorization.where(user: user).delete_all

      expect(execute.payload).to include(complete: true, cursor: nil)
      expect(levels).to contain_exactly([project.id, Gitlab::Access::DEVELOPER])
    end

    it 'returns the rows it wrote' do
      ProjectAuthorization.where(user: user).delete_all

      expect(execute.payload[:written]).to have_attributes(rows_added: 1, rows_deleted: 0)
    end

    it 'removes access the membership no longer grants' do
      GroupMember.where(user: user, source: group).delete_all

      execute

      expect(levels).to contain_exactly([other_project.id, Gitlab::Access::DEVELOPER])
    end

    it 'covers projects in groups the group is invited into' do
      shared_project = create(:project, group: create(:group))
      create(:group_group_link, shared_group: shared_project.group, shared_with_group: group,
        group_access: Gitlab::Access::REPORTER)

      execute

      expect(levels).to include([shared_project.id, Gitlab::Access::REPORTER])
    end

    it 'takes no lock when nothing changed' do
      expect(Authz::ProjectAuthorizations::WriteBatchService).not_to receive(:new)

      execute
    end
  end

  context 'with project IDs' do
    it 'recalculates only those projects' do
      ProjectAuthorization.where(user: user).delete_all

      described_class.new(user.id, project_ids: [other_project.id]).execute

      expect(levels).to contain_exactly([other_project.id, Gitlab::Access::DEVELOPER])
    end

    it "removes rows for projects that don't exist" do
      add_row(non_existing_record_id, Gitlab::Access::DEVELOPER)

      described_class.new(user.id, project_ids: [non_existing_record_id]).execute

      expect(levels.map(&:first)).not_to include(non_existing_record_id)
    end
  end

  context 'with neither' do
    it "repairs the user's whole project set, including rows no reach explains" do
      stale = create(:project)
      ProjectAuthorization.where(user: user).delete_all
      add_row(stale.id, Gitlab::Access::OWNER)

      described_class.new(user.id).execute

      expect(levels).to contain_exactly([project.id, Gitlab::Access::DEVELOPER],
        [other_project.id, Gitlab::Access::DEVELOPER])
    end
  end

  context 'with a runtime limiter' do
    let(:first_id) { [project.id, other_project.id].min }
    let(:last_id) { [project.id, other_project.id].max }

    before do
      stub_const("#{described_class}::SLICE_SIZE", 1)
      ProjectAuthorization.where(user: user).delete_all
    end

    it 'finishes at least one slice, then stops once over time and returns the cursor' do
      result = described_class.new(user.id, runtime_limiter: Gitlab::Metrics::RuntimeLimiter.new(0)).execute

      expect(result.payload).to include(complete: false, cursor: first_id)
      expect(levels.map(&:first)).to eq([first_id])
    end

    it 'resumes after the cursor' do
      result = described_class.new(user.id, cursor: first_id).execute

      expect(result.payload).to include(complete: true, cursor: nil)
      expect(levels.map(&:first)).to eq([last_id])
    end
  end

  it "waits once for writers of the user's lock, before reading the stored rows" do
    stub_const("#{described_class}::SLICE_SIZE", 1)
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] }
    expect(Authz::ProjectAuthorizations::WriteBatchService).to receive(:wait_for_user_writers).once
      .with(user.id).and_call_original

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      described_class.new(user.id, group_ids: [group.id, other_group.id]).execute
    end

    barrier = queries.index { |sql| sql.include?('pg_advisory_xact_lock(') }
    read = queries.index { |sql| sql.include?('FROM "project_authorizations"') }
    expect(barrier).to be < read
  end

  it 'reads the user and the first slice together, then each later slice on its own' do
    stub_const("#{described_class}::SLICE_SIZE", 1)
    user_read = nil
    allow(User).to receive(:find_by_id).and_wrap_original do |original, *args|
      user_read ||= ProjectAuthorization.connection.current_transaction
      original.call(*args)
    end
    slice_reads = {}
    allow(ProjectAuthorization).to receive(:stored_levels_for_user).and_wrap_original do |original, *args|
      slice_reads[args.last] ||= ProjectAuthorization.connection.current_transaction
      original.call(*args)
    end

    described_class.new(user.id, group_ids: [group.id, other_group.id]).execute

    first, second = [project.id, other_project.id].sort.map { |id| slice_reads.fetch([id]) }
    expect(first).to equal(user_read)
    expect(second).not_to equal(user_read)
  end

  it 'does nothing for a user that no longer exists' do
    expect(Authz::ProjectAuthorizations::WriteBatchService).not_to receive(:new)

    result = described_class.new(non_existing_record_id, group_ids: [group.id]).execute

    expect(result.payload).to include(complete: true, cursor: nil)
  end

  context 'when the user is blocked' do
    let_it_be(:blocked_user) { create(:user, :blocked) }

    before_all do
      group.add_developer(blocked_user)
    end

    subject(:execute) { described_class.new(blocked_user.id, group_ids: [group.id]).execute }

    it 'leaves their rows as they are and is complete' do
      expect(Authz::ProjectAuthorizations::WriteBatchService).not_to receive(:new)

      expect(execute.payload).to include(complete: true, cursor: nil)
      expect(ProjectAuthorization.where(user: blocked_user)).to be_empty
    end

    context 'when skip_authorization_refresh_for_blocked_users is disabled' do
      before do
        stub_feature_flags(skip_authorization_refresh_for_blocked_users: false)
      end

      it 'recalculates their rows' do
        execute

        expect(ProjectAuthorization.where(user: blocked_user).pluck(:project_id)).to contain_exactly(project.id)
      end
    end
  end
end
