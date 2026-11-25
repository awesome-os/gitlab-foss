# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::MergeRequests::EmptiedDiffMergeDetector, feature_category: :code_review_workflow do
  include ProjectForksHelper

  let_it_be(:user) { create(:user) }

  # Not shared between examples: they move branches.
  let(:project) { create(:project, :repository) }
  let(:repository) { project.repository }
  let(:tip) { repository.commit('master') }
  let(:pre_rebase_sha) { copy_onto_parent(tip) }

  # The target starts at the tip's parent, so the merge request's only commit is the pre-rebase head.
  let!(:merge_request) do
    repository.create_branch('race-src', pre_rebase_sha)
    repository.create_branch('race-target', tip.parent_id)

    create(:merge_request, source_project: project, source_branch: 'race-src',
      target_project: project, target_branch: 'race-target')
  end

  let!(:previous_diff) { merge_request.merge_request_diff }

  subject(:execute) { described_class.new(merge_request: merge_request, previous_diff: previous_diff).execute }

  # The same change, author and authored date as `commit` under another SHA,
  # like the source branch head before it was rebased.
  def copy_onto_parent(commit, author_name: nil, author_email: nil)
    scratch_branch = "pre-rebase-#{SecureRandom.hex(4)}"
    repository.create_branch(scratch_branch, commit.parent_id)

    repository.cherry_pick(user, commit, scratch_branch, commit.message,
      author_name: author_name, author_email: author_email)
  end

  # Cherry-picks the commits in order onto a new branch at `onto`, like a rebase.
  def pick_onto(onto, *commit_shas)
    branch = "picked-#{SecureRandom.hex(4)}"
    repository.create_branch(branch, onto)

    commit_shas.map do |commit_sha|
      commit = repository.commit(commit_sha)
      repository.cherry_pick(user, commit, branch, commit.message)
    end.last
  end

  def move_branch(branch, sha)
    repository.raw_repository.write_ref("refs/heads/#{branch}", sha)
  end

  # Like the source branch refresh, which loads the merge request after the push.
  def source_refresh
    merge_request.clear_memoized_shas
    merge_request.reload_diff(user)
  end

  # The source branch is rebased onto `tip` and pushed, the target branch is fast-forwarded
  # to it, and then the source branch refresh runs.
  def merge_outside_gitlab
    move_branch('race-src', tip.id)
    move_branch('race-target', tip.id)
    source_refresh
  end

  describe '#execute' do
    it 'starts from a non-empty diff with a pre-rebase head' do
      expect(previous_diff.state).not_to eq('empty')
      expect(previous_diff.head_commit_sha).to eq(pre_rebase_sha)
    end

    context 'when the rebased source branch was fast-forwarded onto the target branch' do
      before do
        merge_outside_gitlab
      end

      it 'returns the head as the merge commit' do
        expect(merge_request.merge_request_diff.state).to eq('empty')
        expect(execute).to eq(tip.id)
      end

      context 'when the merge request is from a fork' do
        before do
          merge_request.source_project = fork_project(project)
        end

        it { is_expected.to be_nil }
      end

      context 'when the previous head has the same author but a different authored date' do
        # Overriding the author makes Gitaly use the current time as the authored date.
        let(:pre_rebase_sha) { copy_onto_parent(tip, author_name: tip.author_name, author_email: tip.author_email) }

        it 'returns nil' do
          previous_head = repository.commit(pre_rebase_sha)

          expect(previous_head.author_email).to eq(tip.author_email)
          expect(previous_head.authored_date).not_to eq(tip.authored_date)
          expect(execute).to be_nil
        end
      end

      context 'when the previous head has a different author but the same authored date' do
        let(:pre_rebase_sha) do
          travel_to(tip.authored_date) do
            copy_onto_parent(tip, author_name: 'Someone Else', author_email: 'someone.else@example.com')
          end
        end

        it 'returns nil' do
          previous_head = repository.commit(pre_rebase_sha)

          expect(previous_head.author_email).not_to eq(tip.author_email)
          expect(previous_head.authored_date).to eq(tip.authored_date)
          expect(execute).to be_nil
        end
      end

      context 'when the merge request has more commits than the check allows' do
        before do
          stub_const("#{described_class}::MAX_MERGE_REQUEST_COMMITS", 0)
        end

        it { is_expected.to be_nil }
      end
    end

    context 'when the target branch merged the rebased source branch with a merge commit' do
      let!(:merge_commit_sha) do
        move_branch('race-src', tip.id)
        repository.merge_to_branch(user, source_sha: tip.id, target_branch: 'race-target', message: 'Merge race-src')
      end

      before do
        source_refresh
      end

      it 'returns the merge commit' do
        expect(merge_commit_sha).not_to eq(tip.id)
        expect(execute).to eq(merge_commit_sha)
      end

      context 'when the target branch has more commits than the walk allows' do
        before do
          stub_const("#{described_class}::MAX_TARGET_COMMITS", 1)
        end

        it { is_expected.to be_nil }
      end
    end

    # Emptying the diff this way merges nothing.
    context 'when the source branch was reset onto the target branch' do
      let(:target_tip) { repository.commit('race-target') }

      before do
        move_branch('race-src', target_tip.id)
        source_refresh
      end

      it 'returns nil' do
        expect(target_tip.authored_date).not_to eq(tip.authored_date)
        expect(merge_request.merge_request_diff.state).to eq('empty')
        expect(execute).to be_nil
      end
    end

    context 'when the merge request has more than one commit' do
      let(:extra_sha) { repository.commit(pre_rebase_sha).parent_id }

      # An extra commit under the pre-rebase head.
      let(:pre_rebase_sha) do
        scratch_branch = "pre-rebase-#{SecureRandom.hex(4)}"
        repository.create_branch(scratch_branch, tip.parent_id)
        repository.create_file(user, 'extra.txt', 'extra', message: 'Add extra file', branch_name: scratch_branch)

        repository.cherry_pick(user, tip, scratch_branch, tip.message)
      end

      # The target branch moves on, so the rebase rewrites both commits. Another author, so it
      # can't match the extra commit.
      let(:target_base_sha) do
        repository.create_file(user, 'target.txt', 'target', message: 'Add target file', branch_name: 'race-target',
          author_name: 'Target Author', author_email: 'target.author@example.com')
      end

      def land(sha)
        move_branch('race-src', sha)
        move_branch('race-target', sha)
        source_refresh
      end

      it 'starts from a diff with both commits' do
        expect(previous_diff.commits_count).to eq(2)
      end

      context 'when both commits were rebased onto the target branch' do
        it 'returns the rebased head' do
          rebased_head_sha = pick_onto(target_base_sha, extra_sha, pre_rebase_sha)

          land(rebased_head_sha)

          expect(merge_request.merge_request_diff.state).to eq('empty')
          expect(execute).to eq(rebased_head_sha)
        end
      end

      # The extra commit never landed.
      context 'when only the head commit was cherry-picked onto the target branch' do
        it 'returns nil' do
          picked_head_sha = pick_onto(target_base_sha, pre_rebase_sha)

          land(picked_head_sha)

          expect(merge_request.merge_request_diff.state).to eq('empty')
          expect(execute).to be_nil
        end
      end
    end

    # For example, a merge request created from an issue, whose branch starts at the target.
    context 'when the previous diff was empty' do
      before do
        previous_diff.update_column(:state, 'empty')
        merge_outside_gitlab
      end

      it { is_expected.to be_nil }
    end

    context 'when the merge request had no stored diff' do
      let!(:previous_diff) { MergeRequestDiff.new(merge_request: merge_request) }

      before do
        merge_outside_gitlab
      end

      it { is_expected.to be_nil }
    end

    # A normal push to the source branch.
    context 'when the new diff is not empty' do
      before do
        move_branch('race-src', tip.id)
        source_refresh
      end

      it 'returns nil without loading commits' do
        expect(merge_request.merge_request_diff.state).not_to eq('empty')
        expect(merge_request.target_project.repository).not_to receive(:commits)

        expect(execute).to be_nil
      end
    end

    context 'when the diff was not reloaded' do
      it 'returns nil without loading commits' do
        expect(merge_request.target_project.repository).not_to receive(:commits)

        expect(execute).to be_nil
      end
    end
  end
end
