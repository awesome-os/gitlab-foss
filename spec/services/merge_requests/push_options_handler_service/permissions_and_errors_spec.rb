# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PushOptionsHandlerService, feature_category: :source_code_management do
  include ProjectForksHelper

  let_it_be(:parent_group) { create(:group, :public) }
  let_it_be(:child_group) { create(:group, :public, parent: parent_group) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, group: child_group) }
  let_it_be(:user1) { create(:user, developer_of: project) }
  let_it_be(:user2) { create(:user, developer_of: project) }
  let_it_be(:forked_project) { fork_project(project, user1, repository: true) }

  let(:service) { described_class.new(project: project, current_user: user1, changes: changes, push_options: push_options) }
  let_it_be(:source_branch) { 'fix' }
  let(:new_branch_changes) { "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:existing_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:default_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{project.default_branch}" }

  before do
    stub_licensed_features(multiple_merge_request_assignees: false)
  end

  describe 'when pushing to a fork with an existing upstream merge request' do
    let_it_be(:attacker) { create(:user) }
    let(:push_options) { { title: 'PWNED TITLE' } }
    let(:changes) { existing_branch_changes }
    let_it_be_with_reload(:upstream_merge_request) do
      create(:merge_request, source_project: project, source_branch: source_branch, title: 'Original title')
    end

    let(:fork_service) do
      described_class.new(
        project: forked_project,
        current_user: attacker,
        changes: changes,
        push_options: push_options
      )
    end

    context 'when an unauthorized user pushes to a fork' do
      before_all do
        forked_project.add_developer(attacker)
      end

      it 'does not update the upstream merge request' do
        expect { fork_service.execute }.not_to change { upstream_merge_request.reload.title }
      end
    end

    context 'when a developer on the upstream project pushes to a fork' do
      before_all do
        forked_project.add_developer(user2) # user2 is already a developer on the upstream project
      end

      let(:fork_service) do
        described_class.new(
          project: forked_project,
          current_user: user2,
          changes: changes,
          push_options: push_options
        )
      end

      it 'does not update the upstream merge request' do
        expect { fork_service.execute }.not_to change { upstream_merge_request.reload.title }
      end
    end

    context 'when the fork owner updates their own fork-to-upstream merge request' do
      let_it_be_with_reload(:fork_merge_request) do
        create(:merge_request, source_project: forked_project, target_project: project,
          source_branch: source_branch, title: 'Original title')
      end

      let(:fork_service) do
        described_class.new(
          project: forked_project,
          current_user: user1,
          changes: changes,
          push_options: push_options
        )
      end

      it 'updates the fork-to-upstream merge request' do
        fork_service.execute

        expect(fork_merge_request.reload.title).to eq('PWNED TITLE')
      end

      it 'does not update the upstream merge request' do
        expect { fork_service.execute }.not_to change { upstream_merge_request.reload.title }
      end
    end
  end

  describe 'when updating a merge request via push options' do
    let(:push_options) { { title: 'Updated title' } }
    let(:changes) { existing_branch_changes }
    let_it_be_with_reload(:merge_request) do
      create(:merge_request, source_project: project, source_branch: source_branch, title: 'Original title')
    end

    context 'when the user is the merge request author' do
      let(:service) do
        described_class.new(project: project, current_user: merge_request.author, changes: changes, push_options: push_options)
      end

      it 'updates the merge request' do
        service.execute

        expect(merge_request.reload.title).to eq('Updated title')
      end
    end

    context 'when the user does not have permission to update the merge request' do
      let_it_be(:unauthorized_user) { create(:user) }
      let(:service) do
        described_class.new(project: project, current_user: unauthorized_user, changes: changes, push_options: push_options)
      end

      before_all do
        project.add_guest(unauthorized_user)
      end

      it 'does not update the merge request' do
        expect { service.execute }.not_to change { merge_request.reload.title }
      end

      it 'records an error' do
        service.execute

        expect(service.errors).to include('User access was denied')
      end
    end
  end

  describe 'multiple pushed branches' do
    let(:push_options) { { create: true } }
    let(:changes) do
      [
        new_branch_changes,
        "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/feature_conflict"
      ]
    end

    it 'creates a merge request per branch' do
      expect { service.execute }.to change { MergeRequest.count }.by(2)
    end

    context 'when there are too many pushed branches' do
      let(:limit) { MergeRequests::PushOptionsHandlerService::LIMIT }
      let(:changes) do
        TestEnv::BRANCH_SHA.to_a[0..limit].map do |x|
          "#{Gitlab::Git::SHA1_BLANK_SHA} #{x.first} refs/heads/#{x.last}"
        end
      end

      it 'records an error' do
        service.execute

        expect(service.errors).to eq(["Too many branches pushed (#{limit + 1} were pushed, limit is #{limit})"])
      end
    end
  end

  describe 'no push options' do
    let(:push_options) { {} }
    let(:changes) { new_branch_changes }

    it_behaves_like 'a service that does nothing'
  end

  describe 'no user' do
    let(:user1) { nil }
    let(:user2) { nil }
    let(:push_options) { { create: true } }
    let(:changes) { new_branch_changes }

    it 'records an error' do
      service.execute

      expect(service.errors).to eq(['User is required'])
    end
  end

  describe 'unauthorized user' do
    let(:push_options) { { create: true } }
    let(:changes) { new_branch_changes }

    it 'records an error', :sidekiq_inline do
      Members::DestroyService.new(ProjectMember.find_by!(user_id: user1.id), current_user: user1).execute

      service.execute

      expect(service.errors).to eq(['User access was denied'])
    end
  end

  describe 'when the user is throttled' do
    let(:push_options) { { create: true } }
    let(:changes) { new_branch_changes }

    before do
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(:merge_requests_create, hash_including(scope: { user: user1 })).and_return(true)
    end

    it 'records a rate limit error without creating a merge request' do
      expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

      expect { service.execute }.not_to change { MergeRequest.count }
      expect(service.errors).to eq(['Merge request creation rate limit exceeded. Try again later.'])
    end
  end

  describe 'handling unexpected exceptions' do
    let(:push_options) { { create: true } }
    let(:changes) { new_branch_changes }
    let(:exception) { StandardError.new('My standard error') }

    def run_service_with_exception
      allow_next_instance_of(MergeRequests::BuildService) do |instance|
        allow(instance).to receive(:execute).and_raise(exception)
      end

      service.execute
    end

    it 'records an error' do
      run_service_with_exception

      expect(service.errors).to eq(['An unknown error occurred'])
    end

    it 'tracks the exception' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        exception, project_id: project.id, branch: source_branch
      )

      run_service_with_exception
    end
  end

  describe 'when target is not a valid branch name' do
    let(:push_options) { { create: true, target: 'my-branch' } }
    let(:changes) { new_branch_changes }

    it 'records an error' do
      service.execute

      expect(service.errors).to eq(["Target branch #{project.full_path}:my-branch does not exist"])
    end
  end

  describe 'when the target project does not exist' do
    let(:push_options) { { create: true, target: 'my-branch', target_project: 'does-not-exist' } }
    let(:changes) { default_branch_changes }

    it 'records an error', :sidekiq_inline do
      service.execute

      expect(service.errors).to eq(["User access was denied"])
    end
  end

  describe 'when user does not have access to target project' do
    let(:push_options) { { create: true, target: 'my-branch' } }
    let(:changes) { default_branch_changes }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user1, :read_code, project).and_return(false)
    end

    it 'records an error', :sidekiq_inline do
      service.execute

      expect(service.errors).to eq(["User access was denied"])
    end
  end

  describe 'when MRs are not enabled' do
    let(:project) { create(:project, :public, :repository, developers: user1) }
    let(:push_options) { { create: true } }
    let(:changes) { new_branch_changes }

    it 'records an error' do
      expect(project).to receive(:merge_requests_enabled?).and_return(false)

      service.execute

      expect(service.errors).to eq(["Merge requests are not enabled for project #{project.full_path}"])
    end
  end

  describe 'when projects are unrelated' do
    let(:unrelated_project) { create(:project, :public, :repository, group: child_group) }
    let(:push_options) { { create: true, target_project: unrelated_project.full_path } }
    let(:changes) { new_branch_changes }

    it 'records an error' do
      service.execute

      expect(service.errors).to eq(["Projects #{project.full_path} and #{unrelated_project.full_path} are not in the same network"])
    end
  end

  describe 'when MR has ActiveRecord errors' do
    let(:push_options) { { create: true } }
    let(:changes) { new_branch_changes }

    it 'adds the error to its errors property' do
      invalid_merge_request = MergeRequest.new
      invalid_merge_request.errors.add(:base, 'my error')

      expect_next_instance_of(MergeRequests::CreateService) do |instance|
        expect(instance).to receive(:execute).and_return(invalid_merge_request)
      end

      service.execute

      expect(service.errors).to eq(['my error'])
    end
  end
end
