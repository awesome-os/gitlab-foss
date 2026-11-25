# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ImportExport::LinkMergeRequestHeadPipelinesService, feature_category: :importers do
  include ProjectForksHelper

  let_it_be(:project) { create(:project, :repository) }

  let_it_be_with_reload(:merge_request_with_mr_pipeline) do
    create(:merge_request, source_project: project, source_branch: 'feature', target_branch: 'master')
  end

  let_it_be_with_reload(:merge_request_with_branch_pipeline) do
    create(:merge_request, source_project: project, source_branch: 'fix', target_branch: 'master')
  end

  let_it_be_with_reload(:merge_request_without_pipeline) do
    create(:merge_request, source_project: project, source_branch: 'markdown', target_branch: 'master')
  end

  let_it_be(:mr_pipeline) do
    create(:ci_pipeline, :detached_merge_request_pipeline, merge_request: merge_request_with_mr_pipeline)
  end

  let_it_be(:branch_pipeline) do
    create(
      :ci_pipeline,
      project: project,
      ref: merge_request_with_branch_pipeline.source_branch,
      sha: merge_request_with_branch_pipeline.diff_head_sha
    )
  end

  let(:limiter) { instance_double(Gitlab::Metrics::RuntimeLimiter, over_time?: false) }
  let(:cursor) { nil }

  subject(:execute) { described_class.new(project).execute(limiter, cursor: cursor) }

  def merge_requests_checked
    checked = []

    allow_next_found_instance_of(MergeRequest) do |merge_request|
      allow(merge_request).to receive(:update_head_pipeline).and_wrap_original do |method|
        checked << merge_request.id
        method.call
      end
    end

    execute

    checked
  end

  it 'links merge requests to their head pipeline' do
    expect(execute.payload).to eq(completed: true, cursor: nil)

    expect(merge_request_with_mr_pipeline.reload.head_pipeline).to eq(mr_pipeline)
    expect(merge_request_with_branch_pipeline.reload.head_pipeline).to eq(branch_pipeline)
    expect(merge_request_without_pipeline.reload.head_pipeline).to be_nil
  end

  it 'skips merge requests without a pipeline for the merge request or its source branch' do
    expect(merge_requests_checked)
      .to contain_exactly(merge_request_with_mr_pipeline.id, merge_request_with_branch_pipeline.id)
  end

  it 'does not run queries per merge request that has no pipeline' do
    described_class.new(project).execute(limiter)
    control = ActiveRecord::QueryRecorder.new { described_class.new(project).execute(limiter) }

    create_list(:merge_request, 3, :closed, source_project: project, source_branch: 'markdown', target_branch: 'master')

    expect { described_class.new(project).execute(limiter) }.not_to exceed_query_limit(control)
  end

  context 'when the merge request only has a merged result pipeline' do
    let_it_be(:merged_result_pipeline) do
      create(:ci_pipeline, :merged_result_pipeline, merge_request: merge_request_without_pipeline)
    end

    it 'links the merged result pipeline' do
      execute

      expect(merge_request_without_pipeline.reload.head_pipeline).to eq(merged_result_pipeline)
    end
  end

  context 'when the source branch only has pipelines for other shas' do
    let_it_be(:other_sha_pipeline) do
      create(:ci_pipeline, project: project, ref: merge_request_without_pipeline.source_branch, sha: 'othersha')
    end

    it 'does not check the merge request' do
      expect(merge_requests_checked).not_to include(merge_request_without_pipeline.id)
    end
  end

  context 'when another branch has a pipeline on the diff head sha' do
    let_it_be(:other_ref_pipeline) do
      create(:ci_pipeline, project: project, ref: 'other-branch', sha: merge_request_without_pipeline.diff_head_sha)
    end

    it 'checks the merge request but does not link the pipeline' do
      expect(merge_requests_checked).to include(merge_request_without_pipeline.id)
      expect(merge_request_without_pipeline.reload.head_pipeline).to be_nil
    end
  end

  context 'when merge requests from another source project use the same branch names' do
    let_it_be(:fork) { fork_project(project, nil, repository: true) }

    let_it_be_with_reload(:fork_merge_request) do
      create(
        :merge_request,
        source_project: fork, target_project: project, source_branch: 'csv', target_branch: 'master'
      )
    end

    let_it_be(:fork_pipeline) do
      create(:ci_pipeline, project: fork, ref: fork_merge_request.source_branch, sha: fork_merge_request.diff_head_sha)
    end

    before_all do
      %w[csv feature markdown].each do |ref|
        create(:ci_pipeline, project: project, ref: ref, sha: 'othersha')
      end

      %w[feature fix markdown].each do |ref|
        create(:ci_pipeline, project: fork, ref: ref, sha: 'othersha')
      end
    end

    it 'links the merge request to the pipeline in its own source project' do
      execute

      expect(fork_merge_request.reload.head_pipeline).to eq(fork_pipeline)
      expect(merge_request_with_branch_pipeline.reload.head_pipeline).to eq(branch_pipeline)
    end
  end

  context 'when the merge request already has a head pipeline' do
    let_it_be(:other_pipeline) do
      create(:ci_pipeline, project: project, ref: merge_request_with_mr_pipeline.source_branch, sha: 'othersha')
    end

    before do
      merge_request_with_mr_pipeline.update_column(:head_pipeline_id, other_pipeline.id)
    end

    it 'does not change the head pipeline' do
      expect { execute }.not_to change { merge_request_with_mr_pipeline.reload.head_pipeline_id }
    end

    it 'does not check the merge request' do
      expect(merge_requests_checked).not_to include(merge_request_with_mr_pipeline.id)
    end
  end

  context 'when the merge request has no diff head sha' do
    before do
      allow_next_found_instance_of(MergeRequest) do |merge_request|
        allow(merge_request).to receive(:diff_head_sha).and_wrap_original do |method|
          merge_request.id == merge_request_with_mr_pipeline.id ? nil : method.call
        end
      end
    end

    it 'skips the merge request' do
      execute

      expect(merge_request_with_mr_pipeline.reload.head_pipeline).to be_nil
    end
  end

  context 'when the runtime limit is reached' do
    let(:limiter) { instance_double(Gitlab::Metrics::RuntimeLimiter, over_time?: true) }

    before do
      stub_const("#{described_class}::BATCH_SIZE", 1)
    end

    it 'stops after the first batch and returns its last iid' do
      expect(execute.payload).to eq(completed: false, cursor: merge_request_with_mr_pipeline.iid)

      expect(merge_request_with_mr_pipeline.reload.head_pipeline).to eq(mr_pipeline)
      expect(merge_request_with_branch_pipeline.reload.head_pipeline).to be_nil
    end

    context 'with a cursor' do
      let(:cursor) { merge_request_with_mr_pipeline.iid }

      it 'resumes after the cursor' do
        expect(execute.payload).to eq(completed: false, cursor: merge_request_with_branch_pipeline.iid)

        expect(merge_request_with_mr_pipeline.reload.head_pipeline).to be_nil
        expect(merge_request_with_branch_pipeline.reload.head_pipeline).to eq(branch_pipeline)
      end
    end

    context 'when no merge request in the batch needs a head pipeline' do
      before do
        merge_request_with_mr_pipeline.update_column(:head_pipeline_id, mr_pipeline.id)
      end

      it 'still moves the cursor past the batch' do
        expect(execute.payload).to eq(completed: false, cursor: merge_request_with_mr_pipeline.iid)
      end
    end
  end
end
