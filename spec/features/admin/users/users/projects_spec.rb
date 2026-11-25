# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Users', feature_category: :user_management do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:common_organization) { create(:common_organization) }
  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:user) do
    create(:omniauth_user, provider: 'twitter', extern_uid: '123456')
  end

  before do
    Users::Internal.in_organization(common_organization).duo_code_review_bot

    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'GET /admin/users/:id/projects' do
    let_it_be(:group) { create(:group, developers: user) }
    let_it_be(:project) { create(:project, group: group) }

    before do
      visit projects_admin_user_path(user)
    end

    it 'lists groups' do
      within('#groups') do
        expect(page).to have_content 'Groups 1'
        expect(page).to have_link group.name, href: admin_group_path(group)
      end
    end

    it 'allows navigation to the group details' do
      within('#groups') do
        click_link group.name
      end
      expect(page).to have_content group.name
      expect(page).to have_content project.name
    end

    it 'shows the group access level' do
      within('#groups') do
        expect(page).to have_content 'Developer'
      end
    end

    it 'allows group membership to be revoked', :js do
      page.within(first('.group_member')) do
        find_by_testid('remove-user').click
      end

      accept_gl_confirm(button_text: 'Remove')

      wait_for_requests

      expect(page).not_to have_selector('.group_member')
    end
  end
end
