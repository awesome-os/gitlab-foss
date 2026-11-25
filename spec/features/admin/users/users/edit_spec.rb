# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Users', feature_category: :user_management do
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

  describe 'GET /admin/users/:id/edit' do
    before do
      visit edit_admin_user_path(user)
    end

    it 'shows all breadcrumbs', :js do
      expect(page_breadcrumbs).to eq([
        { text: 'Admin area', href: admin_root_path },
        { text: 'Users', href: admin_users_path },
        { text: user.name, href: admin_user_path(user) },
        { text: 'Edit', href: edit_admin_user_path(user) }
      ])
    end

    describe 'Update user', :js do
      before do
        fill_in 'user_name', with: 'Big Bang'
        fill_in 'user_email', with: 'bigbang@mail.com'
        fill_in 'user_password', with: 'AValidPassword1'
        fill_in 'user_password_confirmation', with: 'AValidPassword1'
        choose 'Administrator'
        check 'Private profile'
      end

      it 'shows page with new data' do
        click_button 'Save changes'

        # Wait for UI element and wait for requests otherwise test will proceed immediately to assertion
        expect(page).to have_content 'successfully updated'
        wait_for_requests

        expect(page).to have_content('bigbang@mail.com')
        expect(page).to have_content('Big Bang')
      end

      it 'changes user entry' do
        click_button 'Save changes'

        # Wait for UI element and wait for requests otherwise test will proceed immediately to assertion
        expect(page).to have_content 'successfully updated'
        wait_for_requests

        user.reload
        expect(user.name).to eq('Big Bang')
        expect(user.admin?).to be_truthy
        expect(user.password_expires_at).to be <= Time.zone.now
        expect(user.private_profile).to be(true)
      end
    end

    describe 'update username to non ascii char' do
      it 'shows a username error and keeps the original username in the form action' do
        fill_in 'user_username', with: '\u3042\u3044'
        click_button('Save')

        page.within '#error_explanation' do
          expect(page).to have_content('Username')
        end

        expect(page).to have_selector(%(form[action="/admin/users/#{user.username}"]))
      end
    end
  end
end
