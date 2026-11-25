# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PushOptionsHandlerService, feature_category: :source_code_management do
  include ProjectForksHelper

  let_it_be(:parent_group) { create(:group, :public) }
  let_it_be(:child_group) { create(:group, :public, parent: parent_group) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, group: child_group) }
  let_it_be(:user1) { create(:user, developer_of: project) }
  let_it_be(:user2) { create(:user, developer_of: project) }
  let_it_be(:user3) { create(:user, developer_of: project) }

  let(:service) { described_class.new(project: project, current_user: user1, changes: changes, push_options: push_options) }
  let_it_be(:source_branch) { 'fix' }
  let(:new_branch_changes) { "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:existing_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{source_branch}" }
  let(:deleted_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 #{Gitlab::Git::SHA1_BLANK_SHA} refs/heads/#{source_branch}" }
  let(:default_branch_changes) { "d14d6c0abdd253381df51a723d58691b2ee1ab08 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{project.default_branch}" }
  let(:error_mr_required) { "A merge_request.create push option is required to create a merge request for branch #{source_branch}" }

  before do
    stub_licensed_features(multiple_merge_request_assignees: false)
  end

  shared_examples 'with an existing branch that has a merge request open in foss' do
    let(:changes) { existing_branch_changes }
    let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, source_branch: source_branch) }

    it_behaves_like 'a service that does not create a merge request'
    it_behaves_like 'a service that can change assignees of a merge request', 1
  end

  describe '`assign` push option' do
    let(:assigned) { { user2.id => 1, user3.id => 1 } }
    let(:unassigned) { nil }
    let(:push_options) { { assign: assigned, unassign: unassigned } }

    it_behaves_like 'with a new branch', 1
    it_behaves_like 'with an existing branch but no open MR', 1
    it_behaves_like 'with an existing branch that has a merge request open in foss'

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'

    context 'when passing in usernames' do
      # makes sure that usernames starting with numbers aren't treated as IDs
      let(:user2) { create(:user, username: '123user', developer_of: project) }
      let(:user3) { create(:user, username: '999user', developer_of: project) }
      let(:assigned) { { user2.username => 1, user3.username => 1 } }

      it_behaves_like 'with an existing branch that has a merge request open in foss'
    end
  end

  describe '`unassign` push option' do
    let(:assigned) { { user2.id => 1, user3.id => 1 } }
    let(:unassigned) { { user1.id => 1, user3.id => 1 } }
    let(:push_options) { { assign: assigned, unassign: unassigned } }

    it_behaves_like 'with a new branch', 1
    it_behaves_like 'with an existing branch but no open MR', 1
    it_behaves_like 'with an existing branch that has a merge request open in foss'

    it_behaves_like 'with a deleted branch'
    it_behaves_like 'with the project default branch'

    context 'when passing in usernames' do
      let(:assigned) { { user2.username => 1, user3.username => 1 } }
      let(:unassigned) { { user1.username => 1, user3.username => 1 } }

      it_behaves_like 'with an existing branch that has a merge request open in foss'
    end
  end
end
