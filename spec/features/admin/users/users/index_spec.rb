# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Users', feature_category: :user_management do
  include Features::AdminUsersHelpers

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

  describe 'GET /admin/users', :js do
    before do
      visit admin_users_path(filter: 'active')
    end

    it "is ok" do
      expect(page).to have_current_path(admin_users_path, ignore_query: true)
    end

    it "has users list" do
      admin.reload

      expect(has_user?(text: admin.name)).to be(true)
      expect(has_user?(text: admin.created_at.strftime('%b %d, %Y'))).to be(true)
      expect(has_user?(text: user.email)).to be(true)
      expect(has_user?(text: user.name)).to be(true)
      expect(page).to have_content('Projects')

      click_user_dropdown_toggle(user.id)

      expect(page).to have_button('Block')
      expect(page).to have_button('Deactivate')
      expect(page).to have_button('Delete user')
      expect(page).to have_button('Delete user and contributions')
    end

    it 'clicking edit user takes us to edit page', :aggregate_failures do
      within_testid("user-actions-#{user.id}") do
        click_link 'Edit'
      end

      expect(page).to have_content('Name')
      expect(page).to have_content('Password')
    end

    it 'shows the user popover on hover', :js do
      expect(has_testid?('user-popover', count: 0)).to be(true)

      within('body.page-initialised') do
        find_link(user.email).hover

        within_testid('user-popover') do
          expect(page).to have_content user.name
          expect(page).to have_content user.username
          expect(page).to have_button 'Follow'
        end
      end
    end

    context 'user project count' do
      before do
        create(:project, maintainers: admin)
      end

      it 'displays count of users projects' do
        visit admin_users_path

        within_testid("user-project-count-#{admin.id}") do
          expect(page).to have_content('1')
        end
      end
    end

    describe 'internal users' do
      context 'when showing a `Ghost User`' do
        let_it_be(:ghost_user) { create(:user, :ghost) }

        it 'does not render actions dropdown' do
          expect(page).not_to have_css(
            "[data-testid='user-actions-#{ghost_user.id}'] [data-testid='user-actions-dropdown-toggle']")
        end
      end

      context 'when showing a `Bot User`' do
        let_it_be(:bot_user) { create(:user, user_type: :alert_bot) }

        it 'does not render actions dropdown' do
          expect(page).not_to have_css(
            "[data-testid='user-actions-#{bot_user.id}'] [data-testid='user-actions-dropdown-toggle']")
        end
      end
    end

    context 'user group count', :js do
      before do
        create(:group, developers: admin)
        create(:project, group: create(:group), reporters: admin)
      end

      it 'displays count of the users authorized groups' do
        visit admin_users_path

        wait_for_requests

        within_testid("user-group-count-#{admin.id}") do
          expect(page).to have_content('2')
        end
      end
    end
  end
end
