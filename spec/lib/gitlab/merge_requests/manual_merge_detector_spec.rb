# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::MergeRequests::ManualMergeDetector, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project, :repository) }

  # Pushing `oldrev..newrev` to `feature` lands the tip of `master` on it.
  let_it_be_with_reload(:merge_request) do
    create(:merge_request, source_project: project, source_branch: 'master',
      target_project: project, target_branch: 'feature')
  end

  let_it_be(:oldrev) { merge_request.commits.last.id }
  let_it_be(:newrev) { merge_request.commits.first.id }

  let(:branch_name) { 'feature' }
  let(:commits) { project.repository.commits_between(oldrev, newrev) }

  subject(:execute) { described_class.new(project: project, branch_name: branch_name, commits: commits).execute }

  describe '#execute' do
    context 'when the stored diff head is in the push' do
      it 'returns the merge request with its merge commit' do
        expect(execute).to eq(merge_request => newrev)
      end
    end

    context 'when the stored diff head is not in the push' do
      before do
        merge_request.merge_request_diff.update_column(:head_commit_sha, oldrev)
      end

      it { is_expected.to be_empty }
    end

    context 'when the push has no commits' do
      let(:commits) { [] }

      it { is_expected.to be_empty }
    end

    context 'when the push is to another branch' do
      let(:branch_name) { 'test' }

      it { is_expected.to be_empty }
    end

    context 'when the merge request is not open' do
      before do
        merge_request.close!
      end

      it { is_expected.to be_empty }
    end

    # An empty diff can't be told apart from a merged one.
    context 'when the merge request diff is empty' do
      before do
        merge_request.merge_request_diff.update_column(:state, 'empty')
      end

      it { is_expected.to be_empty }
    end

    # Deleting a source fork nullifies source_project_id.
    context 'when the source project has been deleted' do
      before do
        merge_request.update_column(:source_project_id, nil)
      end

      it { is_expected.to be_empty }
    end
  end
end
