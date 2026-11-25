# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PushOptionsHandlerService, feature_category: :source_code_management do
  include ProjectForksHelper

  let_it_be(:parent_group) { create(:group, :public) }
  let_it_be(:child_group) { create(:group, :public, parent: parent_group) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, group: child_group) }
  let_it_be(:user1) { create(:user, developer_of: project) }
  let_it_be(:parent_group_milestone) { create(:milestone, group: parent_group, title: 'ParentGroupMilestone1.0') }
  let_it_be(:child_group_milestone) { create(:milestone, group: child_group, title: 'ChildGroupMilestone1.0') }
  let_it_be(:project_milestone) { create(:milestone, project: project, title: 'ProjectMilestone1.0') }

  let(:service) { described_class.new(project: project, current_user: user1, changes: changes, push_options: push_options) }
  let_it_be(:source_branch) { 'fix' }
  let(:label1) { 'mylabel1' }
  let(:label2) { 'mylabel2' }
  let(:label3) { 'mylabel3' }
  let(:new_branch_changes) { "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:existing_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:deleted_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 #{Gitlab::Git::SHA1_BLANK_SHA} refs/heads/#{source_branch}" }
  let(:default_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{project.default_branch}" }
  let(:error_mr_required) { "A merge_request.create push option is required to create a merge request for branch #{source_branch}" }

  before do
    stub_licensed_features(multiple_merge_request_assignees: false)
  end

  shared_examples_for 'a service that can set the milestone of a merge request' do
    subject(:last_mr) { MergeRequest.last }

    it 'sets the milestone' do
      service.execute

      expect(last_mr.milestone&.title).to eq(expected_milestone)
    end
  end

  shared_examples_for 'a service that can change labels of a merge request' do |count|
    subject(:last_mr) { MergeRequest.last }

    it 'changes label count' do
      service.execute

      expect(last_mr.label_ids.count).to eq(count)
    end
  end

  describe '`label` push option' do
    let(:push_options) { { label: { label1 => 1, label2 => 1 } } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, label: { label1 => 1, label2 => 1 } } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can change labels of a merge request', 2
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
        let(:push_options) { { create: true, label: { label1 => 1, label2 => 1 } } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can change labels of a merge request', 2
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can change labels of a merge request', 2
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`unlabel` push option' do
    let(:push_options) { { label: { label1 => 1, label2 => 1 }, unlabel: { label1 => 1, label3 => 1 } } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, label: { label1 => 1, label2 => 1 }, unlabel: { label1 => 1, label3 => 1 } } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can change labels of a merge request', 1
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
        let(:push_options) { { create: true, label: { label1 => 1, label2 => 1 }, unlabel: { label1 => 1, label3 => 1 } } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can change labels of a merge request', 1
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can change labels of a merge request', 1
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`milestone` push option' do
    context 'with a valid milestone' do
      let(:expected_milestone) { project_milestone.title }
      let(:push_options) { { milestone: project_milestone.title } }

      context 'with a new branch' do
        let(:changes) { new_branch_changes }

        it_behaves_like 'a service that does not create a merge request'

        it 'adds an error to the service' do
          service.execute

          expect(service.errors).to include(error_mr_required)
        end

        context 'when coupled with the `create` push option' do
          let(:push_options) { { create: true, milestone: project_milestone.title } }

          it_behaves_like 'a service that can create a merge request'
          it_behaves_like 'a service that can set the milestone of a merge request'
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
          let(:push_options) { { create: true, milestone: project_milestone.title } }

          it_behaves_like 'a service that can create a merge request'
          it_behaves_like 'a service that can set the milestone of a merge request'
        end
      end

      context 'with an existing branch that has a merge request open' do
        let(:changes) { existing_branch_changes }
        let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

        it_behaves_like 'a service that does not create a merge request'
        it_behaves_like 'a service that can set the milestone of a merge request'
      end

      it_behaves_like 'with a deleted branch'
      it_behaves_like 'with the project default branch'
    end

    context 'with invalid milestone' do
      let(:expected_milestone) { nil }
      let(:changes) { new_branch_changes }
      let(:push_options) { { create: true, milestone: 'invalid_milestone' } }

      it_behaves_like 'a service that can set the milestone of a merge request'
    end

    context 'with an ancestor milestone' do
      let(:changes) { existing_branch_changes }

      context 'with immediate parent milestone' do
        let(:push_options) { { create: true, milestone: child_group_milestone.title } }
        let(:expected_milestone) { child_group_milestone.title }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the milestone of a merge request'
      end

      context 'with multi-level ancestor milestone' do
        let(:push_options) { { create: true, milestone: parent_group_milestone.title } }
        let(:expected_milestone) { parent_group_milestone.title }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the milestone of a merge request'
      end
    end
  end
end
