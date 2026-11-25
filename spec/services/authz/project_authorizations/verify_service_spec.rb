# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::ProjectAuthorizations::VerifyService, feature_category: :permissions do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  let(:service) { described_class.new }

  def sample(*pairs)
    allow_next_instance_of(Authz::ProjectAuthorizations::VerificationSample) do |sample|
      allow(sample).to receive(:pairs).and_return(pairs)
    end
  end

  def queued_repairs
    Authz::ProjectAuthorizations::RefreshEvent.where(target_type: :user_in_project).pluck(:target_id, :scope_id)
  end

  def drift_log_line(cause, **levels)
    hash_including('message' => 'Project authorization drift found', 'cause' => cause, 'gl_user_id' => user.id,
      'gl_project_id' => project.id, **levels.stringify_keys)
  end

  before do
    Authz::ProjectAuthorizations::RefreshEvent.delete_all
    ProjectAuthorization.where(user: user, project: project).delete_all
    ProjectAuthorization.insert_all([{ user_id: user.id, project_id: project.id,
                                       access_level: Gitlab::Access::DEVELOPER, is_unique: true }])
  end

  it 'counts matching pairs and reports every outcome' do
    sample([user.id, project.id])

    expect(service.execute.payload).to eq(sampled: 1, matches: 1, drift: 0, unconfirmed_drift: 0,
      calculations_disagree: 0, duplicate_rows: 0, suppressed: 0, deleted_project: 0, blocked_user: 0, failed: 0,
      complete: true)
  end

  it 'reads each pair in one repeatable read snapshot' do
    sample([user.id, project.id])
    connection = ProjectAuthorization.connection
    allow(connection).to receive(:transaction_open?).and_return(false)

    expect(connection).to receive(:transaction).with(isolation: :repeatable_read).and_yield

    expect(service.execute.payload).to include(matches: 1)
  end

  context 'when a row is missing' do
    before do
      ProjectAuthorization.where(user: user, project: project).delete_all
      sample([user.id, project.id])
    end

    it 'queues a repair and logs the drift when nothing pending could fix it' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(drift_log_line('drift', stored_level: 0,
        expected_level: Gitlab::Access::DEVELOPER, project_level: Gitlab::Access::DEVELOPER))

      expect(service.execute.payload).to include(drift: 1)
      expect(queued_repairs).to match_array([[user.id, project.id]])
    end

    it 'repairs it with the calculation it compared against' do
      service.execute
      Authz::ProjectAuthorizations::RefreshService.new(Gitlab::Metrics::RuntimeLimiter.new(10.minutes)).execute

      expect(ProjectAuthorization.where(user: user, project: project).pluck(:access_level))
        .to eq([Gitlab::Access::DEVELOPER])
    end

    where(:target_type, :target) do
      :user_in_group   | ->(user, _project, group) { [user.id, group.id] }
      :user            | ->(user, _project, _group) { [user.id, nil] }
      :user_in_project | ->(user, project, _group) { [user.id, project.id] }
      :project         | ->(_user, project, _group) { [project.id, nil] }
    end

    with_them do
      it 'waits while an event for the user or the project is pending' do
        Authz::ProjectAuthorizations::RefreshEvent.enqueue(target_type, [target.call(user, project, group)])

        expect(service.execute.payload).to include(suppressed: 1, drift: 0)
      end
    end

    it "waits while a share into the project's group is pending" do
      Authz::ProjectAuthorizations::RefreshEvent.enqueue(:group_group_link, [[create(:group).id, group.id]])

      expect(service.execute.payload).to include(suppressed: 1)
    end

    it 'waits while a namespace or share event anywhere is pending' do
      Authz::ProjectAuthorizations::RefreshEvent.enqueue(:namespace_subtree, [create(:group).id])

      expect(service.execute.payload).to include(suppressed: 1)
    end

    it "doesn't let poison events hold it up" do
      create(:authz_refresh_event, target_type: :user_in_group, target_id: user.id, scope_id: group.id,
        attempts: Authz::ProjectAuthorizations::RefreshEvent::POISON_ATTEMPTS)

      expect(service.execute.payload).to include(drift: 1)
    end

    it 'records and logs the difference without queueing a repair until memberships compute' do
      stub_feature_flags(authz_refresh_compute_memberships: false)

      expect(Projects::Members::EffectiveAccessLevelPerUserFinder).not_to receive(:new)
      expect(Gitlab::AppJsonLogger).to receive(:info).with(drift_log_line('unconfirmed_drift'))

      expect(service.execute.payload).to include(unconfirmed_drift: 1)
      expect(queued_repairs).to be_empty
    end

    it "records a difference the project refresh's calculation agrees with the row on, without a repair" do
      allow_next_instance_of(Projects::Members::EffectiveAccessLevelPerUserFinder) do |finder|
        allow(finder).to receive(:execute).and_return([])
      end

      expect(Gitlab::AppJsonLogger).to receive(:info).with(drift_log_line('calculations_disagree'))

      expect(service.execute.payload).to include(calculations_disagree: 1)
      expect(queued_repairs).to be_empty
    end
  end

  it 'finds a row that grants more than the calculation' do
    ProjectAuthorization.where(user: user, project: project).update_all(access_level: Gitlab::Access::MAINTAINER)
    sample([user.id, project.id])

    expect(service.execute.payload).to include(drift: 1)
    expect(queued_repairs).to match_array([[user.id, project.id]])
  end

  it 'counts legacy duplicate rows whose highest level is right apart from drift' do
    ProjectAuthorization.insert_all([{ user_id: user.id, project_id: project.id,
                                       access_level: Gitlab::Access::GUEST, is_unique: false }])
    sample([user.id, project.id])

    expect(service.execute.payload).to include(duplicate_rows: 1, drift: 0)
    expect(queued_repairs).to be_empty
  end

  it 'counts a pair that fails and checks the rest' do
    other = create(:project, group: group)
    sample([user.id, other.id], [user.id, project.id])
    calls = 0
    allow(Authz::UserProjectGrants).to receive(:new).and_wrap_original do |original, *args, **kwargs|
      calls += 1
      raise ActiveRecord::QueryCanceled if calls == 1

      original.call(*args, **kwargs)
    end

    expect(Gitlab::ErrorTracking).to receive(:track_exception)
      .with(instance_of(ActiveRecord::QueryCanceled), user_id: user.id, project_id: other.id)

    expect(service.execute.payload).to include(sampled: 2, failed: 1, matches: 1)
  end

  it 'skips rows of deleted projects and projects pending deletion' do
    pending_delete = create(:project, group: group, pending_delete: true)
    sample([user.id, non_existing_record_id], [user.id, pending_delete.id])

    expect(service.execute.payload).to include(deleted_project: 2)
    expect(queued_repairs).to be_empty
  end

  context 'when the user is blocked' do
    let_it_be(:blocked) { create(:user, :blocked, developer_of: group) }

    it 'skips them, since their rows are left as they are until they are active again' do
      sample([blocked.id, project.id])

      expect(service.execute.payload).to include(blocked_user: 1, sampled: 1)
      expect(queued_repairs).to be_empty
    end
  end

  it 'stops once over its time limit' do
    stub_const("#{described_class}::MAX_RUNTIME", 0)
    sample([user.id, project.id])

    expect(service.execute.payload).to include(sampled: 0, complete: false)
  end

  it 'counts the outcomes in a metric' do
    sample([user.id, project.id])
    counter = instance_double(Prometheus::Client::Counter, increment: nil)
    allow(Gitlab::Metrics).to receive(:counter).and_return(counter)

    service.execute

    expect(counter).to have_received(:increment).with({ outcome: :matches }, 1)
  end

  it 'checks the pairs VerificationSample picks' do
    expect(Authz::ProjectAuthorizations::VerificationSample).to receive(:new).with(described_class::SAMPLE_SIZE)
      .and_call_original

    expect(service.execute.payload).to include(sampled: be >= 1, failed: 0)
  end
end
