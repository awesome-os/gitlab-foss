# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MembersDestroyer::UnassignIssuablesWorker, feature_category: :user_management do
  let_it_be(:group) { create(:group, :private) }
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:requesting_user) { create(:user) }

  context 'when unsupported membership source entity' do
    it 'exits early and logs error' do
      params = { message: "SomeEntity is not a supported entity.", entity_type: 'SomeEntity', entity_id: group.id, user_id: user.id, requesting_user_id: requesting_user.id }

      expect(Sidekiq.logger).to receive(:error).with(params)

      described_class.new.perform(user.id, group.id, 'SomeEntity', requesting_user.id)
    end
  end

  context 'when requesting_user_id is nil' do
    it 'exits early and logs error' do
      params = { message: "requesting_user_id is nil.", entity_type: 'Group', entity_id: group.id, user_id: user.id, requesting_user_id: nil }

      expect(Sidekiq.logger).to receive(:error).with(params)

      described_class.new.perform(user.id, group.id, 'Group', nil)
    end
  end

  it "calls the Members::UnassignIssuablesService with the params it was given" do
    service = double

    expect(Members::UnassignIssuablesService).to receive(:new).with(user, group, requesting_user).and_return(service)
    expect(service).to receive(:execute).and_return(ServiceResponse.success)

    described_class.new.perform(user.id, group.id, 'Group', requesting_user.id)
  end

  it 'unassigns the issues and merge requests and logs their counts and timings', :aggregate_failures do
    project = create(:project, group: group)
    group.add_maintainer(requesting_user)
    create(:issue, project: project, assignees: [user])
    create(:merge_request, :simple, source_project: project, assignees: [user])

    worker = described_class.new
    worker.perform(user.id, group.id, 'Group', requesting_user.id)

    expect(user.assigned_issues.count).to eq(0)
    expect(user.assigned_merge_requests.count).to eq(0)
    expect(worker.logging_extras).to include(
      'extra.members_destroyer_unassign_issuables_worker.processed_issues_count' => 1,
      'extra.members_destroyer_unassign_issuables_worker.issues_batches_count' => 1,
      'extra.members_destroyer_unassign_issuables_worker.issues_lookup_duration_s' => be_positive,
      'extra.members_destroyer_unassign_issuables_worker.issues_update_duration_s' => be_positive,
      'extra.members_destroyer_unassign_issuables_worker.processed_merge_requests_count' => 1,
      'extra.members_destroyer_unassign_issuables_worker.merge_requests_batches_count' => 1,
      'extra.members_destroyer_unassign_issuables_worker.merge_requests_lookup_duration_s' => be_positive,
      'extra.members_destroyer_unassign_issuables_worker.merge_requests_update_duration_s' => be_positive
    )
  end
end
