# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::MergeHeadDiffMatchService, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.creator }

  let(:repository) { project.repository }
  let(:suffix) { SecureRandom.hex(4) }
  let(:target_branch) { "match-target-#{suffix}" }
  let(:source_branch) { "match-source-#{suffix}" }

  let(:merge_request) do
    create(:merge_request, source_project: project, target_project: project,
      source_branch: source_branch, target_branch: target_branch)
  end

  # Lazy, so each context commits to the branches before the merge.
  let(:merge_ref) do
    MergeRequests::MergeToRefService.new(project: project, current_user: user).execute(merge_request)
      .slice(:commit_id, :target_id, :source_id)
  end

  let(:service) { described_class.new(merge_request, merge_ref) }

  subject(:outcome) { service.outcome }

  def commit(branch, actions)
    repository.commit_files(user, branch_name: branch, message: 'match spec', actions: actions)
  end

  def lines(tag)
    (1..30).map { |i| "#{tag} line #{i}\n" }.join
  end

  # Builds the real merge-head diff to compare the outcome against.
  def rebuilt_merge_head_diff_files
    merge_ref
    MergeRequests::ReloadMergeHeadDiffService.new(merge_request).execute

    merge_request.reset.merge_head_diff.raw_diffs.map { |diff| [diff.old_path, diff.new_path, diff.diff] }
  end

  def regular_diff_files
    merge_request.merge_request_diff.raw_diffs.map { |diff| [diff.old_path, diff.new_path, diff.diff] }
  end

  before do
    repository.add_branch(user, target_branch, 'master')
    commit(target_branch, [
      { action: :create, file_path: 'match/shared.txt', content: lines('shared') },
      { action: :create, file_path: 'match/other.txt', content: lines('other') },
      { action: :create, file_path: 'match/moved.txt', content: lines('moved') }
    ])
    repository.add_branch(user, source_branch, target_branch)
    commit(source_branch, [
      { action: :update, file_path: 'match/shared.txt', content: lines('shared').sub('shared line 3', 'MR line 3') },
      { action: :create, file_path: 'match/added.bin', content: "\x00\x01binary".b },
      { action: :move, previous_path: 'match/moved.txt', file_path: 'match/renamed.txt', content: lines('moved') }
    ])
  end

  shared_examples 'a merge-head diff equal to the regular diff' do
    it { is_expected.to eq(:matches_regular_diff) }

    it 'is a match' do
      expect(service.match?).to be(true)
    end

    it 'matches the merge-head diff a rebuild writes' do
      expect(regular_diff_files).to match_array(rebuilt_merge_head_diff_files)
    end
  end

  context 'when the target has not moved since the merge base' do
    it_behaves_like 'a merge-head diff equal to the regular diff'
  end

  context 'when the target changed, added and deleted files the merge request does not touch' do
    before do
      commit(target_branch, [
        { action: :update, file_path: 'match/other.txt', content: lines('changed on target') },
        { action: :create, file_path: 'match/target_only.txt', content: "new\n" }
      ])
      commit(target_branch, [{ action: :delete, file_path: 'match/target_only.txt' }])
    end

    it_behaves_like 'a merge-head diff equal to the regular diff'
  end

  context 'when the target changed a file the merge request changes' do
    before do
      commit(target_branch, [
        {
          action: :update, file_path: 'match/shared.txt',
          content: lines('shared').sub('shared line 6', 'target line 6')
        }
      ])
    end

    it { is_expected.to eq(:changes_differ) }

    it 'is not a match' do
      expect(service.match?).to be(false)
    end

    it 'would write a different merge-head diff' do
      expect(regular_diff_files).not_to match_array(rebuilt_merge_head_diff_files)
    end
  end

  context 'when the target already has the change the merge request makes' do
    before do
      commit(target_branch, [
        { action: :update, file_path: 'match/shared.txt', content: lines('shared').sub('shared line 3', 'MR line 3') }
      ])
    end

    it { is_expected.to eq(:changes_differ) }
  end

  context 'when the regular diff overflowed' do
    before do
      merge_request.merge_request_diff.update_column(:state, :overflow)
    end

    it { is_expected.to eq(:regular_diff_not_collected) }
  end

  context 'when the source shares no history with the target' do
    let(:merge_request) do
      create(:merge_request, source_project: project, target_project: project,
        source_branch: 'orphaned-branch', target_branch: target_branch)
    end

    it 'has no merge base to compare from' do
      expect(merge_request.merge_request_diff.base_commit_sha).to be_nil
      expect(outcome).to eq(:no_merge_base)
    end
  end

  context 'when the merge ref was built from another source commit' do
    let(:service) do
      described_class.new(merge_request, merge_ref.merge(source_id: repository.commit(target_branch).id))
    end

    it { is_expected.to eq(:source_moved) }
  end

  context 'when Gitaly fails' do
    before do
      merge_ref # build it before the failure

      allow(project.repository.raw_repository).to receive(:find_changed_paths!)
        .and_raise(Gitlab::Git::CommandError, 'boom')
      allow(merge_request.project).to receive(:repository).and_return(project.repository)
    end

    it { is_expected.to eq(:git_error) }

    context 'with an invalid argument' do
      before do
        allow(project.repository.raw_repository).to receive(:find_changed_paths!).and_raise(ArgumentError, 'boom')
      end

      it { is_expected.to eq(:git_error) }
    end
  end
end
