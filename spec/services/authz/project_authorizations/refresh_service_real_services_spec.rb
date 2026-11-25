# frozen_string_literal: true

require 'spec_helper'

# The services and callbacks production runs, with both groups' old Sidekiq refreshes off, so the database triggers
# and the refresh queue are all that keep project_authorizations right.
RSpec.describe Authz::ProjectAuthorizations::RefreshService, 'with the real services', :aggregate_failures,
  feature_category: :permissions do
  include_context 'with only the refresh queue writing project authorizations'

  let_it_be(:owner) { create(:user) }
  let_it_be(:root) { create(:group, owners: owner) }
  let_it_be(:subgroup) { create(:group, parent: root) }
  let_it_be_with_reload(:invited) { create(:group, owners: owner) }
  let_it_be(:other) { create(:group, owners: owner) }
  let_it_be(:root_project) { create(:project, group: root) }
  let_it_be_with_reload(:sub_project) { create(:project, group: subgroup) }
  let_it_be(:shared_project) { create(:project, group: other) }
  let_it_be_with_reload(:member) { create(:user, developer_of: subgroup) }
  let_it_be(:invited_member) { create(:user, developer_of: invited) }
  let_it_be(:newcomer) { create(:user) }
  let_it_be_with_reload(:group_share) do
    create(:group_group_link, shared_group: subgroup, shared_with_group: invited,
      group_access: Gitlab::Access::DEVELOPER)
  end

  let_it_be_with_reload(:project_share) do
    create(:project_group_link, project: shared_project, group: invited, group_access: Gitlab::Access::REPORTER)
  end

  let(:users) { [owner, member, invited_member, newcomer] }

  it 'starts every user from rows the queue wrote' do
    expect(stored_authorizations(users)).to match_array(expected_authorizations(users))
    expect(project_ids_of(invited_member)).to contain_exactly(sub_project.id, shared_project.id)
  end

  describe 'members' do
    it 'adds a group member' do
      refresh_through_queue do
        Members::CreateService.new(owner, user_id: newcomer.id, access_level: Gitlab::Access::DEVELOPER,
          source: subgroup, invite_source: 'spec').execute
      end

      expect(project_ids_of(newcomer)).to contain_exactly(sub_project.id)
    end

    it "changes a group member's access level" do
      refresh_through_queue do
        Members::UpdateService.new(owner, access_level: Gitlab::Access::MAINTAINER, source: subgroup)
          .execute(subgroup.members.find_by(user: member))
      end

      expect(stored_authorizations([member])).to contain_exactly([member.id, sub_project.id, Gitlab::Access::MAINTAINER])
    end

    it 'removes a group member' do
      refresh_through_queue do
        Members::DestroyService.new(subgroup.members.find_by(user: member), current_user: owner).execute
      end

      expect(stored_authorizations([member])).to be_empty
    end

    it 'adds a project member' do
      refresh_through_queue do
        Members::CreateService.new(owner, user_id: newcomer.id, access_level: Gitlab::Access::DEVELOPER,
          source: root_project, invite_source: 'spec').execute
      end

      expect(project_ids_of(newcomer)).to contain_exactly(root_project.id)
    end
  end

  describe 'group shares' do
    it 'shares a group with another group' do
      refresh_through_queue do
        Groups::GroupLinks::CreateService.new(other, subgroup, owner, shared_group_access: Gitlab::Access::GUEST)
          .execute
      end

      expect(project_ids_of(member)).to include(shared_project.id)
    end

    it "changes a group share's access level" do
      refresh_through_queue do
        Groups::GroupLinks::UpdateService.new(group_share, owner).execute(group_access: Gitlab::Access::REPORTER)
      end

      expect(stored_authorizations([invited_member]))
        .to include([invited_member.id, sub_project.id, Gitlab::Access::REPORTER])
    end

    it 'removes a group share' do
      refresh_through_queue { Groups::GroupLinks::DestroyService.new(subgroup, owner).execute(group_share) }

      expect(project_ids_of(invited_member)).not_to include(sub_project.id)
    end

    it 'deletes a group that was invited into other groups and projects' do
      refresh_through_queue { Groups::DestroyService.new(invited, owner).execute }

      expect(project_ids_of(invited_member)).to be_empty
    end
  end

  describe 'project shares' do
    it 'shares a project with a group' do
      refresh_through_queue do
        Projects::GroupLinks::CreateService.new(root_project, invited, owner,
          link_group_access: Gitlab::Access::DEVELOPER).execute
      end

      expect(project_ids_of(invited_member)).to include(root_project.id)
    end

    it 'removes a project share' do
      refresh_through_queue { Projects::GroupLinks::DestroyService.new(shared_project, owner).execute(project_share) }

      expect(project_ids_of(invited_member)).not_to include(shared_project.id)
    end
  end

  describe 'projects' do
    it 'moves a project to another group' do
      refresh_through_queue { Projects::TransferService.new(sub_project, owner).execute(other) }

      expect(project_ids_of(member)).not_to include(sub_project.id)
    end

    it 'creates a project' do
      refresh_through_queue do
        Projects::CreateService.new(owner, name: 'Queued', path: 'queued', namespace_id: subgroup.id).execute
      end

      expect(project_ids_of(member)).to include(subgroup.projects.find_by(path: 'queued').id)
    end
  end

  describe 'users', :enable_admin_mode do
    it 'activates a deactivated user' do
      # Clear the user's rows, so only the activation's refresh can bring them back.
      member.update_column(:state, 'deactivated')
      ProjectAuthorization.where(user: member).delete_all

      refresh_through_queue { Users::ActivateService.new(create(:admin)).execute(member) }

      expect(project_ids_of(member)).to contain_exactly(sub_project.id)
    end
  end
end
