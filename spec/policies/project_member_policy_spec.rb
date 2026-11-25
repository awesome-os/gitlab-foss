# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectMemberPolicy, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:member_user) { create(:user) }
  let(:member) { create(:project_member, project: project, user: member_user) }
  let(:current_user) { maintainer }

  subject { described_class.new(current_user, member) }

  before do
    create(:project_member, :maintainer, project: project, user: maintainer)
  end

  it { is_expected.to delegate_to(ProjectPolicy) }
  it { expect(described_class).to override_delegates_for(:delete_project_member) }

  context 'with a regular member' do
    it { expect_allowed(:update_project_member, :delete_project_member) }
    it { expect_disallowed(:delete_project_bot_member) }
  end

  context 'when the current user cannot manage members' do
    let_it_be(:developer) { create(:user) }
    let(:current_user) { developer }

    before do
      create(:project_member, :developer, project: project, user: developer)
    end

    it { expect_disallowed(:update_project_member, :delete_project_member) }

    context 'when the membership is their own' do
      let(:member) { project.members.find_by!(user: developer) }

      it { expect_allowed(:delete_project_member) }
    end
  end

  context 'when the member holds the personal namespace the project is in' do
    let_it_be(:member) { project.members.find_by!(user: project.namespace.owner) }

    it { expect_disallowed(:update_project_member, :delete_project_member) }
  end

  context 'with a bot member' do
    let_it_be(:member_user) { create(:user, :project_bot) }

    it { expect_allowed(:delete_project_bot_member) }
    it { expect_disallowed(:update_project_member, :delete_project_member) }
  end

  shared_examples 'read-only project member policy' do
    context 'with a regular member' do
      it { expect_disallowed(:update_project_member) }
      it { expect_allowed(:delete_project_member) }
    end

    context 'with a bot member' do
      let_it_be(:member_user) { create(:user, :project_bot) }

      it { expect_allowed(:delete_project_bot_member) }
    end

    context 'when the current user cannot manage members' do
      let_it_be(:developer) { create(:user) }
      let(:current_user) { developer }

      before do
        create(:project_member, :developer, project: project, user: developer)
      end

      it { expect_disallowed(:update_project_member, :delete_project_member) }
    end
  end

  context 'when the project is scheduled for deletion' do
    let_it_be(:project) { create(:project, marked_for_deletion_at: 1.day.ago) }

    it_behaves_like 'read-only project member policy'
  end

  context 'when the project is archived' do
    let_it_be(:project) { create(:project, :archived) }

    it_behaves_like 'read-only project member policy'
  end

  describe 'withdraw_member_access_request' do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:user) { create(:user) }

    let(:current_user) { user }

    context 'with their own access request' do
      let_it_be(:member) { create(:project_member, :access_request, project: project, user: user) }

      it { expect_allowed(:withdraw_member_access_request) }
    end

    context "with another user's access request" do
      let_it_be(:member) { create(:project_member, :access_request, project: project, user: create(:user)) }

      it { expect_disallowed(:withdraw_member_access_request) }
    end

    context 'with their own active membership' do
      let_it_be(:member) { create(:project_member, :developer, project: project, user: user) }

      it { expect_disallowed(:withdraw_member_access_request) }
    end
  end
end
