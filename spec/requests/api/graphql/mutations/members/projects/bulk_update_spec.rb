# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ProjectMemberBulkUpdate', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:parent_group) { create(:group) }
  let_it_be(:parent_group_member) { create(:group_member, group: parent_group) }
  let_it_be(:project) { create(:project, group: parent_group) }
  let_it_be(:source) { project }
  let_it_be(:member_type) { :project_member }
  let_it_be(:mutation_name) { :project_member_bulk_update }
  let_it_be(:source_id_key) { 'project_id' }
  let_it_be(:response_member_field) { 'projectMembers' }

  it_behaves_like 'members bulk update mutation'

  context 'when the user cannot update project members' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:member) { create(:project_member, project: project) }

    let(:mutation) do
      graphql_mutation(mutation_name, {
        source_id_key => project.to_global_id.to_s,
        'user_ids' => [member.user.to_global_id.to_s],
        'access_level' => 'GUEST'
      })
    end

    before_all do
      project.add_owner(current_user)
    end

    before do
      stub_ability(current_user, project, update_project_member: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end
end
