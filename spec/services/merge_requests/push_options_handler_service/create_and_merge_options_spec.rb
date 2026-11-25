# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PushOptionsHandlerService, feature_category: :source_code_management do
  include ProjectForksHelper

  let_it_be(:parent_group) { create(:group, :public) }
  let_it_be(:child_group) { create(:group, :public, parent: parent_group) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, group: child_group) }
  let_it_be(:user1) { create(:user, developer_of: project) }

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

  shared_examples_for 'a service that can set the merge request to auto merge' do
    subject(:last_mr) { MergeRequest.last }

    let(:change) { Gitlab::ChangesList.new(changes).changes.first }

    it 'sets auto_merge_enabled' do
      service.execute

      expect(last_mr.auto_merge_enabled).to be(true)
      expect(last_mr.auto_merge_strategy).to eq(AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS)
      expect(last_mr.merge_user).to eq(user1)
      expect(last_mr.merge_params['sha']).to eq(change[:newrev])
    end
  end

  shared_examples_for 'a service that can remove the source branch when it is merged' do
    subject(:last_mr) { MergeRequest.last }

    it 'returns true to force_remove_source_branch?' do
      service.execute

      expect(last_mr.force_remove_source_branch?).to be(true)
    end
  end

  describe '`create` push option' do
    let(:push_options) { { create: true } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that can create a merge request'
    end

    context 'with an existing branch but no open MR' do
      let(:changes) { existing_branch_changes }

      it_behaves_like 'a service that can create a merge request'
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`auto_merge` push option' do
    let(:push_options) { { auto_merge: true } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, auto_merge: true } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the merge request to auto merge'
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
        let(:push_options) { { create: true, auto_merge: true } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the merge request to auto merge'
      end
    end

    context 'when the user cannot merge into the target branch' do
      let(:merge_error) do
        "merge_request.auto_merge was not applied: you do not have permission " \
          "to merge into #{project.full_path}:#{project.default_branch}"
      end

      before do
        create(:protected_branch, :maintainers_can_merge, project: project, name: project.default_branch)
      end

      context 'when creating a merge request' do
        let(:push_options) { { create: true, auto_merge: true } }
        let(:changes) { new_branch_changes }

        it_behaves_like 'a service that can create a merge request'

        it 'does not enable auto-merge and reports the missing permission' do
          service.execute

          expect(MergeRequest.last.auto_merge_enabled).to be(false)
          expect(service.errors).to include(merge_error)
        end
      end

      context 'when updating an existing merge request' do
        let(:push_options) { { auto_merge: true } }
        let(:changes) { existing_branch_changes }
        let_it_be_with_reload(:merge_request) do
          create(:merge_request, source_project: project, source_branch: source_branch,
            target_project: project, target_branch: project.default_branch)
        end

        it 'does not enable auto-merge and reports the missing permission' do
          service.execute

          expect(merge_request.reload.auto_merge_enabled).to be(false)
          expect(service.errors).to include(merge_error)
        end
      end

      context 'when the push switches the target to the protected branch' do
        let(:push_options) { { auto_merge: true, target: project.default_branch } }
        let(:changes) { existing_branch_changes }
        let_it_be_with_reload(:merge_request) do
          create(:merge_request, source_project: project, source_branch: source_branch,
            target_project: project, target_branch: target_branch)
        end

        it 'does not enable auto-merge and reports the missing permission' do
          service.execute

          expect(merge_request.reload.auto_merge_enabled).to be(false)
          expect(service.errors).to include(merge_error)
        end
      end
    end
  end

  describe '`merge_when_pipeline_succeeds` push option' do
    let(:push_options) { { merge_when_pipeline_succeeds: true } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, merge_when_pipeline_succeeds: true } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the merge request to auto merge'
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
        let(:push_options) { { create: true, merge_when_pipeline_succeeds: true } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the merge request to auto merge'
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can set the merge request to auto merge'
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`remove_source_branch` push option' do
    let(:push_options) { { remove_source_branch: true } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, remove_source_branch: true } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can remove the source branch when it is merged'
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
        let(:push_options) { { create: true, remove_source_branch: true } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can remove the source branch when it is merged'
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can remove the source branch when it is merged'
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end
end
