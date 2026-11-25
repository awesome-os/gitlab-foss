# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Users', feature_category: :user_management do
  include Features::AdminUsersHelpers
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

  describe 'GET /admin/users', :js do
    before do
      visit admin_users_path(filter: 'active')
    end

    context 'when blocking/unblocking a user' do
      it 'shows confirmation and allows blocking and unblocking', :js do
        expect(has_user?(text: user.email)).to be(true)

        click_action_in_user_dropdown(user.id, 'Block')

        wait_for_requests

        expect(page).to have_content('Block user')
        expect(page).to have_content('Blocking user has the following effects')
        expect(page).to have_content('User will not be able to login')
        expect(page).to have_content('Owned groups will be left')

        find('.modal-footer button', text: 'Block').click

        wait_for_requests

        expect(page).to have_content('Successfully blocked')
        expect(has_user?(text: user.email)).to be(false)

        visit admin_users_path(filter: 'blocked')

        wait_for_requests

        expect(has_user?(text: user.email)).to be(true)

        click_action_in_user_dropdown(user.id, 'Unblock')

        expect(page).to have_content('Unblock user')
        expect(page).to have_content('You can always block their account again if needed.')

        find('.modal-footer button', text: 'Unblock').click

        wait_for_requests

        expect(page).to have_content('Successfully unblocked')
        expect(has_user?(text: user.email)).to be(false)
      end
    end

    context 'when deactivating/re-activating a user' do
      it 'shows confirmation and allows deactivating and re-activating', :js do
        expect(has_user?(text: user.email)).to be(true)

        click_action_in_user_dropdown(user.id, 'Deactivate')

        expect(page).to have_content('Deactivate user')
        expect(page).to have_content('Deactivating a user has the following effects')
        expect(page).to have_content('The user will be logged out')
        expect(page).to have_content('Personal projects, group and user history will be left intact')

        find('.modal-footer button', text: 'Deactivate').click

        wait_for_requests

        expect(page).to have_content('Successfully deactivated')
        expect(page).not_to have_content(user.email)

        visit admin_users_path(filter: 'deactivated')

        wait_for_requests

        expect(has_user?(text: user.email)).to be(true)

        click_action_in_user_dropdown(user.id, 'Activate')

        expect(page).to have_content('Activate user')
        expect(page).to have_content('You can always deactivate their account again if needed.')

        find('.modal-footer button', text: 'Activate').click

        wait_for_requests

        expect(page).to have_content('Successfully activated')
        expect(has_user?(text: user.email)).to be(false)
      end
    end

    context 'when a user is locked', time_travel_to: '2020-02-25 10:30:45 -0700' do
      let_it_be(:locked_user) { create(:user, locked_at: DateTime.parse('2020-02-25 10:30:00 -0700')) }

      it "displays `Locked` badge next to user" do
        expect(page).to have_content("#{locked_user.name} #{locked_user.email} Locked")
      end

      it 'allows a user to be unlocked from the `User administration dropdown', :js do
        accept_gl_confirm("Unlock user #{locked_user.name}?", button_text: 'Unlock') do
          click_action_in_user_dropdown(locked_user.id, 'Unlock')
        end

        expect(page).not_to have_content("#{locked_user.name} Locked")
      end
    end

    describe 'users pending approval' do
      it 'sends a welcome email and a password reset email to the user upon admin approval', :sidekiq_inline do
        user = create(:user, :blocked_pending_approval, created_by_id: admin.id)

        visit admin_users_path(filter: 'blocked_pending_approval')

        click_user_dropdown_toggle(user.id)

        find_by_testid('approve').click

        expect(page).to have_content("Approve user #{user.name}?")

        perform_enqueued_jobs do
          within_modal do
            click_button 'Approve'
          end

          expect(page).to have_content('Successfully approved')
        end

        welcome_email = ActionMailer::Base.deliveries.find { |m| m.subject == 'Welcome to GitLab!' }
        expect(welcome_email.to).to eq([user.email])
        expect(welcome_email.text_part.body).to have_content('Your GitLab account request has been approved!')

        password_reset_email = ActionMailer::Base.deliveries.find { |m| m.subject == 'Account was created for you' }
        expect(password_reset_email.to).to eq([user.email])
        expect(password_reset_email.text_part.body).to have_content('Click here to set your password')

        expect(ActionMailer::Base.deliveries.count).to eq(2)
      end
    end

    context 'user pending approval' do
      it 'shows user info', :aggregate_failures do
        user = create(:user, :blocked_pending_approval)

        visit admin_users_path(filter: 'blocked_pending_approval')
        click_link user.name

        expect(page).to have_content(user.name)
        expect(page).to have_content('Pending approval')

        click_user_dropdown_toggle(user.id)

        expect(page).to have_button('Approve')
        expect(page).to have_button('Reject')
      end
    end
  end
end
