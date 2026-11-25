# frozen_string_literal: true

RSpec.shared_context 'with merge requests API setup' do
  include ProjectForksHelper

  let_it_be(:base_time) { Time.now }
  let_it_be_with_refind(:user) { create(:user) }
  let_it_be(:user2, freeze: false) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be_with_refind(:project) do
    create(:project, :public, :repository, creator: user, namespace: user.namespace,
      only_allow_merge_if_pipeline_succeeds: false)
  end
  let(:allowed_query_threshold) { 3 } # Threshold required for N + 1 specs to pass, see: https://gitlab.com/gitlab-org/gitlab/-/work_items/587748.

  let(:milestone1) { create(:milestone, title: '0.9', project: project) }
  let(:milestone) { create(:milestone, title: '1.0.0', project: project) }
  let(:label) { create(:label, title: 'label', color: '#FFAABB', project: project) }
  let(:label2) { create(:label, title: 'a-test', color: '#FFFFFF', project: project) }

  let(:merge_request) do
    create(:merge_request, :simple, author: user, assignees: [user], source_project: project, target_project: project,
      source_branch: 'markdown', title: "Test", created_at: base_time)
  end

  before_all do
    project.add_reporter(user)
    project.add_reporter(user2)
  end

  before do
    stub_licensed_features(multiple_merge_request_assignees: false)
  end

  # @note In a new database, a merge request id can equal an iid in the project.
  #   This moves that iid out of the way, so the id finds no merge request.
  def merge_request_id_not_used_as_iid
    project.merge_requests.where(iid: merge_request.id).update_all(iid: non_existing_record_iid)

    merge_request.id
  end

  shared_context 'with merge requests' do
    let_it_be(:milestone1) { create(:milestone, title: '0.9', project: project) }
    let_it_be(:merge_request_merged) do
      create(:merge_request, :with_merged_metrics, state: "merged", author: user, assignees: [user],
        source_project: project, target_project: project, title: "Merged test",
        created_at: base_time + 2.seconds, updated_at: base_time + 1.hour,
        merge_commit_sha: '9999999999999999999999999999999999999999', merged_by: user)
    end

    let_it_be(:merge_request, freeze: false) do
      create(:merge_request, :simple, milestone: milestone1, author: user, assignees: [user], source_project: project,
        target_project: project, source_branch: 'markdown', title: "Test",
        created_at: base_time, updated_at: base_time + 3.hours)
    end

    let_it_be(:merge_request_closed) do
      create(:merge_request, state: "closed", milestone: milestone1, author: user, assignees: [user],
        source_project: project, target_project: project, title: "Closed test",
        created_at: base_time + 1.second, updated_at: base_time)
    end

    let_it_be(:merge_request_locked) do
      create(:merge_request, state: "locked", milestone: milestone1, author: user, assignees: [user],
        source_project: project, target_project: project, title: "Locked test",
        created_at: base_time + 1.second, updated_at: base_time + 2.hours)
    end

    let_it_be(:note) do
      create(:note_on_merge_request, author: user, project: project, noteable: merge_request, note: "a comment on a MR")
    end

    let_it_be(:note2) do
      create(:note_on_merge_request, author: user, project: project, noteable: merge_request,
        note: "another comment on a MR")
    end
  end

  shared_context 'with a merge request created once' do
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :simple, author: user, assignees: [user], source_project: project, target_project: project,
        source_branch: 'markdown', title: "Test", created_at: base_time)
    end
  end

  shared_context 'with labels' do
    before do
      create(:label_link, label: label, target: merge_request)
      create(:label_link, label: label2, target: merge_request)
    end
  end
end
