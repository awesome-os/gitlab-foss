# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::UnresolvedNotesPreloader, feature_category: :code_review_workflow do
  let_it_be(:project_requiring_resolved_threads) do
    create(:project, :repository, only_allow_merge_if_all_discussions_are_resolved: true)
  end

  let_it_be(:other_project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project_requiring_resolved_threads) }
  let_it_be(:merge_request_with_thread) do
    create(:merge_request, :unique_branches, source_project: project_requiring_resolved_threads)
  end

  let_it_be(:other_merge_request) { create(:merge_request, source_project: other_project) }

  before_all do
    create(:discussion_note_on_merge_request, noteable: merge_request_with_thread,
      project: project_requiring_resolved_threads)
  end

  def load_merge_requests(ids)
    MergeRequest.id_in(ids).preload(:target_project).to_a
  end

  def execute(merge_requests)
    described_class.new(merge_requests).execute
  end

  it 'lets mergeable_discussions_state? answer without a notes query', :aggregate_failures do
    merge_requests = load_merge_requests([merge_request.id, merge_request_with_thread.id, other_merge_request.id])
    execute(merge_requests)

    states = nil
    recorder = ActiveRecord::QueryRecorder.new do
      states = merge_requests.to_h { |mr| [mr.id, mr.mergeable_discussions_state?] }
    end

    expect(states).to eq(
      merge_request.id => true, merge_request_with_thread.id => false, other_merge_request.id => true
    )
    expect(recorder.log.grep(/FROM "notes"/)).to be_empty
  end

  it 'does not run more queries for more merge requests of the same project' do
    control_merge_requests = load_merge_requests([merge_request.id])
    control = ActiveRecord::QueryRecorder.new { execute(control_merge_requests) }

    merge_requests = load_merge_requests([merge_request.id, merge_request_with_thread.id])

    expect { execute(merge_requests) }.not_to exceed_query_limit(control)
  end
end
