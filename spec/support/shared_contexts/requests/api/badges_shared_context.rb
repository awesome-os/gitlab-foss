# frozen_string_literal: true

RSpec.shared_context 'with API badges setup' do
  let_it_be(:maintainer) { create(:user, username: 'maintainer_user') }
  let_it_be(:developer) { create(:user) }
  let_it_be(:access_requester) { create(:user) }
  let_it_be(:stranger) { create(:user) }
  let_it_be(:project_group) { create(:group) }
  let_it_be_with_reload(:group) { setup_group }
  let_it_be_with_reload(:project) { setup_project }

  shared_context 'source helpers' do
    def get_source(source_type)
      source_type == 'project' ? project : group
    end
  end

  def setup_project
    create(:project, :public, creator_id: maintainer.id, namespace: project_group) do |project|
      project.add_developer(developer)
      project.add_maintainer(maintainer)
      project.request_access(access_requester)
      project.project_badges << build(:project_badge, project: project, name: 'ExampleBadge1')
      project.project_badges << build(:project_badge, project: project, name: 'ExampleBadge2')
      project_group.badges << build(:group_badge, group: group, name: 'ExampleBadge3')
    end
  end

  def setup_group
    create(:group, :public) do |group|
      group.add_developer(developer)
      group.add_owner(maintainer)
      group.request_access(access_requester)
      group.badges << build(:group_badge, group: group, name: 'ExampleBadge4')
      group.badges << build(:group_badge, group: group, name: 'ExampleBadge5')
    end
  end
end
