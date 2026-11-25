# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item detail', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be_with_refind(:user) { create(:user) }
  let_it_be_with_refind(:user2) { create(:user, name: 'John') }

  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :public, group: group) }
  let_it_be_with_refind(:label) { create(:label, project: project, title: "testing-label") }
  let_it_be_with_refind(:label2) { create(:label, project: project, title: "another-label") }
  let_it_be_with_refind(:work_item) { create(:work_item, project: project, labels: [label]) }
  let_it_be_with_refind(:task) { create(:work_item, :task, project: project) }
  let_it_be_with_refind(:emoji_upvote) { create(:award_emoji, :upvote, awardable: work_item, user: user2) }
  let_it_be_with_refind(:milestone) { create(:milestone, project: project) }
  let_it_be_with_refind(:milestones) { create_list(:milestone, 3, project: project) }
  let_it_be_with_refind(:note) { create(:note, noteable: work_item, project: work_item.project) }
  let_it_be_with_refind(:contact) { create(:contact, group: group) }
  let(:contact_name) { "#{contact.first_name} #{contact.last_name}" }
  let(:list_path) { project_work_items_path(project) }
  let(:work_items_path) { project_work_item_path(project, work_item.iid) }

  context 'for signed in user' do
    let(:linked_item) { task }

    before_all do
      group.add_developer(user)
    end

    before do
      stub_const("AutocompleteSources::ExpiresIn::AUTOCOMPLETE_EXPIRES_IN", 0)
      sign_in(user)
      visit work_items_path
    end

    it 'shows breadcrumb links', :aggregate_failures do
      within_testid('breadcrumb-links') do
        expect(page).to have_link(project.name, href: project_path(project))
        expect(page).to have_link('Work items', href: project_work_items_path(project))
        expect(find('nav:last-of-type li:last-of-type')).to have_link("##{work_item.iid}", href: work_items_path)
      end
    end

    # Title, confidentiality and notifications are covered by
    # ee/spec/frontend/integration/work_items/drawer_shared_test_helpers.js
    it_behaves_like 'work items description'
    it_behaves_like 'work items award emoji'

    # Hiding and showing closed linked items is covered by
    # ee/spec/frontend/integration/work_items/details/linked_items_spec.js
    it_behaves_like 'work items linked items'

    context 'for task work item type' do
      let(:work_item) { task }
      let(:linked_item) { create(:work_item, :task, project: project) }

      before do
        visit project_work_item_path(project, task.iid)
      end

      it_behaves_like 'work items linked items'
    end

    it_behaves_like 'work items comments'

    it_behaves_like 'work items todos'

    it_behaves_like 'work items lock discussion', 'issue'

    # Closing, reopening and assigning are covered by
    # ee/spec/frontend/integration/work_items/drawer_shared_test_helpers.js
    it_behaves_like 'work items assignees real-time'
    it_behaves_like 'work items labels', 'project'

    it_behaves_like 'work items milestone accessibility'

    it_behaves_like 'work items time tracking'

    it_behaves_like 'work items crm contacts'
  end

  context 'when item is a task' do
    before_all do
      project.add_developer(user)
    end

    before do
      sign_in(user)
      visit project_work_item_path(project, task.iid)
    end

    it_behaves_like 'work items parent', :issue
    # Changing the type is covered by spec/features/work_items/detail/change_type_action_spec.rb
  end

  context 'for signed in admin', :enable_admin_mode do
    let_it_be_with_refind(:admin) { create(:admin) }

    context 'with akismet integration' do
      let_it_be_with_refind(:user_agent_detail) { create(:user_agent_detail, subject: work_item) }

      before_all do
        project.add_maintainer(admin)
      end

      before do
        stub_application_setting(akismet_enabled: true)
        sign_in(admin)
        visit work_items_path
      end

      it_behaves_like 'work items submit as spam'
    end
  end

  context 'for signed in owner' do
    before_all do
      project.add_owner(user)
    end

    before do
      sign_in(user)
      visit work_items_path
    end

    it_behaves_like 'work items invite members'
  end

  context 'for guest users' do
    before_all do
      project.add_guest(user)
    end

    context 'for work item authored by guest user' do
      let_it_be_with_refind(:key_result) { create(:work_item, :key_result, author: user, project: project) }
      let_it_be_with_refind(:note) { create(:note, noteable: key_result, project: key_result.project) }

      before do
        sign_in(user)
        visit project_work_item_path(project, key_result.iid)
      end

      it_behaves_like 'authored work item guest user permissions'
    end

    context 'for work item not authored by guest user' do
      before do
        sign_in(user)
        visit work_items_path
      end

      it_behaves_like 'non-authored work item guest user permissions'
    end
  end

  # The signed-out drawer and the development widget are covered by
  # ee/spec/frontend/integration/work_items/details/signed_out_spec.js
end
