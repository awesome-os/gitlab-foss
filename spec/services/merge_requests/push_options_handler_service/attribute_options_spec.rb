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
  let(:title) { 'my title' }
  let(:draft_title) { 'Draft: my title' }
  let(:draft) { true }
  let(:squash) { true }
  let(:description) { 'my description' }
  let(:multiline_description) do
    <<~MD.chomp
      Line 1
      Line 2
      Line 3
    MD
  end

  let(:new_branch_changes) { "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:existing_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:deleted_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 #{Gitlab::Git::SHA1_BLANK_SHA} refs/heads/#{source_branch}" }
  let(:default_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{project.default_branch}" }
  let(:error_mr_required) { "A merge_request.create push option is required to create a merge request for branch #{source_branch}" }

  before do
    stub_licensed_features(multiple_merge_request_assignees: false)
  end

  shared_examples_for 'a service that can set the title of a merge request' do
    subject(:last_mr) { MergeRequest.last }

    it 'sets the title' do
      service.execute

      expect(last_mr.title).to eq(title)
    end
  end

  shared_examples_for 'a service that can set the description of a merge request' do
    subject(:last_mr) { MergeRequest.last }

    it 'sets the description' do
      service.execute

      expect(last_mr.description).to eq(description)
    end
  end

  shared_examples_for 'a service that can set the multiline description of a merge request' do
    subject(:last_mr) { MergeRequest.last }

    it 'sets the multiline description' do
      service.execute

      expect(last_mr.description).to eq(multiline_description)
    end
  end

  shared_examples_for 'a service that can set the draft of a merge request' do
    subject(:last_mr) { MergeRequest.last }

    it 'sets the draft' do
      service.execute

      expect(last_mr.draft).to eq(draft)
    end
  end

  shared_examples_for 'a service that can set a merge request to be squashed' do
    subject(:last_mr) { MergeRequest.last }

    it 'sets the squash property' do
      service.execute

      expect(last_mr.squash).to eq(squash)
    end
  end

  describe '`title` push option' do
    let(:push_options) { { title: title } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, title: title } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the title of a merge request'
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
        let(:push_options) { { create: true, title: title } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the title of a merge request'
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can set the title of a merge request'
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`description` push option' do
    let(:push_options) { { description: description } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, description: description } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the description of a merge request'
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
        let(:push_options) { { create: true, description: description } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the description of a merge request'
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can set the description of a merge request'

      context 'with a multiline description' do
        let(:push_options) { { description: "Line 1\\nLine 2\\nLine 3" } }

        it_behaves_like 'a service that does not create a merge request'
        it_behaves_like 'a service that can set the multiline description of a merge request'
      end
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`draft` push option' do
    let(:push_options) { { draft: draft } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, draft: draft } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the draft of a merge request'
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
        let(:push_options) { { create: true, draft: draft } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set the draft of a merge request'
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can set the draft of a merge request'
    end

    context 'draft title provided while `draft` push option is set to false' do
      let(:push_options) { { create: true, draft: false, title: draft_title } }
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that can create a merge request'
      it_behaves_like 'a service that can set the draft of a merge request'
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end

  describe '`squash` push option' do
    let(:push_options) { { squash: squash } }

    context 'with a new branch' do
      let(:changes) { new_branch_changes }

      it_behaves_like 'a service that does not create a merge request'

      it 'adds an error to the service' do
        service.execute

        expect(service.errors).to include(error_mr_required)
      end

      context 'when coupled with the `create` push option' do
        let(:push_options) { { create: true, squash: squash } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set a merge request to be squashed'

        context 'when squash is false' do
          let(:squash) { false }

          it_behaves_like 'a service that can set a merge request to be squashed'
        end
      end

      context 'when project squash_option is always' do
        let(:push_options) { { create: true } }

        before do
          project.project_setting.update!(squash_option: 'always')
        end

        it 'creates a merge request without the required squash blocker', :aggregate_failures do
          service.execute

          merge_request = MergeRequest.last

          expect(merge_request.squash).to be(true)
          expect(merge_request.missing_required_squash?).to be(false)
        end
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
        let(:push_options) { { create: true, squash: squash } }

        it_behaves_like 'a service that can create a merge request'
        it_behaves_like 'a service that can set a merge request to be squashed'

        context 'when squash is false' do
          let(:squash) { false }

          it_behaves_like 'a service that can set a merge request to be squashed'
        end
      end
    end

    context 'with an existing branch that has a merge request open' do
      let(:changes) { existing_branch_changes }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

      it_behaves_like 'a service that does not create a merge request'
      it_behaves_like 'a service that can set a merge request to be squashed'
    end

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'
  end
end
