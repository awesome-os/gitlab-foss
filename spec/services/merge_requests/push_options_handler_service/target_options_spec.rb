# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PushOptionsHandlerService, feature_category: :source_code_management do
  include ProjectForksHelper

  let_it_be(:parent_group) { create(:group, :public) }
  let_it_be(:child_group) { create(:group, :public, parent: parent_group) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, group: child_group) }
  let_it_be(:user1) { create(:user, developer_of: project) }
  let_it_be(:forked_project) { fork_project(project, user1, repository: true) }

  let(:service) { described_class.new(project: project, current_user: user1, changes: changes, push_options: push_options) }
  let_it_be(:source_branch) { 'fix' }
  let_it_be(:target_branch) { 'feature' }
  let(:new_branch_changes) { "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:existing_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:deleted_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 #{Gitlab::Git::SHA1_BLANK_SHA} refs/heads/#{source_branch}" }
  let(:default_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{project.default_branch}" }
  let(:error_mr_required) { "A merge_request.create push option is required to create a merge request for branch #{source_branch}" }

  before do
    stub_licensed_features(multiple_merge_request_assignees: false)
  end

  shared_examples_for 'a service that can set the target of a merge request' do
    subject(:last_mr) { MergeRequest.last }

    it 'sets the target_branch' do
      service.execute

      expect(last_mr.target_branch).to eq(target_branch)
    end
  end

  shared_examples_for 'a service that can set the target project of a merge request' do
    subject(:last_mr) { MergeRequest.last }

    it 'creates a merge request with the correct target project' do
      project_path = push_options[:target_project] || project.default_merge_request_target.full_path

      expect { service.execute }.to change { MergeRequest.count }.by(1)
      expect(last_mr.target_project.full_path).to eq(project_path)
    end
  end

  describe 'pushing from default branch' do
    let(:changes) { default_branch_changes }

    context 'with target branch specified' do
      let(:push_options) { { create: true, target: target_branch } }

      it_behaves_like 'a service that can create a merge request'
      it_behaves_like 'a service that can set the target of a merge request'
    end

    context 'without target branch specified' do
      let(:push_options) { { create: true } }

      it_behaves_like 'a service that does nothing'
    end
  end

  describe '`target` push option' do
    let(:push_options) { { target: target_branch } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, target: target_branch } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the target of a merge request'
      end
    end

    context 'with an existing branch but no open MR' do
      let(:changes) { existing_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, target: target_branch } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the target of a merge request'
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can set the target of a merge request'
    end

    context 'when target is not a usable branch name' do
      let(:changes) { new_branch_changes }
      let(:invalid_target_error) { 'A merge_request.target push option value must be a branch name' }

      context 'when target has no value' do
        let(:push_options) { { create: true, target: true } }

        it 'records an error without creating a merge request', :aggregate_failures do
          expect { service.execute }.not_to change { MergeRequest.count }

          expect(service.errors).to eq([invalid_target_error])
        end
      end

      context 'when target is empty' do
        let(:push_options) { { create: true, target: '' } }

        it 'records an error without creating a merge request', :aggregate_failures do
          expect { service.execute }.not_to change { MergeRequest.count }

          expect(service.errors).to eq([invalid_target_error])
        end
      end

      context 'with ref_existence_check_gitaly enabled' do
        let(:push_options) { { create: true, target: true } }

        before do
          allow(project.repository).to receive(:branch_exists?).and_call_original
        end

        it 'does not check a non-string branch name', :aggregate_failures do
          expect { service.execute }.not_to raise_error

          expect(project.repository).not_to have_received(:branch_exists?).with(true)
          expect(service.errors).to include(invalid_target_error)
        end
      end

      context 'when pushing the default branch with target having no value' do
        let(:changes) { default_branch_changes }
        let(:push_options) { { create: true, target: true } }

        it 'records an error without creating a merge request', :aggregate_failures do
          expect { service.execute }.not_to change { MergeRequest.count }

          expect(service.errors).to eq([invalid_target_error])
        end
      end
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`target_project` push option' do
    let(:changes) { new_branch_changes }
    let_it_be(:double_forked_project) { fork_project(forked_project, user1, repository: true) }
    let(:service) { described_class.new(project: double_forked_project, current_user: user1, changes: changes, push_options: push_options) }
    let(:push_options) { { create: true, target_project: target_project.full_path } }

    context 'to self' do
      let(:target_project) { double_forked_project }

      it_behaves_like 'a service that can set the target project of a merge request'
    end

    context 'to intermediate project' do
      let(:target_project) { forked_project }

      it_behaves_like 'a service that can set the target project of a merge request'
    end

    context 'to base project' do
      let(:target_project) { project }

      it_behaves_like 'a service that can set the target project of a merge request'
    end
  end
end
