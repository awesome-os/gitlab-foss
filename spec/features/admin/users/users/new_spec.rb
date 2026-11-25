# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Users', feature_category: :user_management do
  include ListboxHelpers

  let_it_be(:common_organization) { create(:common_organization) }
  let_it_be(:admin) { create(:admin) }

  before do
    Users::Internal.in_organization(common_organization).duo_code_review_bot

    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'GET /admin/users/new' do
    let_it_be(:user_username) { 'bang' }

    before do
      visit new_admin_user_path
      fill_in 'user_name', with: 'Big Bang'
      fill_in 'user_username', with: user_username
      fill_in 'user_email', with: 'bigbang@mail.com'
    end

    it 'creates new user' do
      expect { click_create_user! }.to change { User.count }.by(1)
    end

    it 'applies defaults to user' do
      click_create_user!

      user = User.find_by(username: 'bang')
      expect(user.projects_limit)
        .to eq(Gitlab.config.gitlab.default_projects_limit)
      expect(user.can_create_group)
        .to eq(Gitlab::CurrentSettings.can_create_group)
      expect(user.private_profile)
        .to eq(Gitlab::CurrentSettings.user_defaults_to_private_profile)
    end

    it 'creates user with valid data' do
      click_create_user!

      user = User.find_by(username: 'bang')
      expect(user.name).to eq('Big Bang')
      expect(user.email).to eq('bigbang@mail.com')
    end

    it 'calls send mail' do
      expect_next_instance_of(NotificationService) do |instance|
        expect(instance).to receive(:new_user)
      end

      click_button 'Create user'
    end

    it 'sends valid email to user with email & password' do
      perform_enqueued_jobs do
        click_create_user!
      end

      user = User.find_by(username: 'bang')
      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to have_content('Account was created')
      expect(email.text_part.body).to have_content(user.email)
      expect(email.text_part.body).to have_content('password')
    end

    context 'username contains spaces' do
      let_it_be(:user_username) { 'Bing bang' }

      it "doesn't create the user and shows an error message" do
        expect { click_button 'Create user' }.not_to change { User.count }

        expect(page).to have_content('The form contains the following error')
        expect(page).to have_content('Username can contain only letters, digits')
      end
    end

    it 'assigns correct organization access level', :js do
      within_testid 'organization-section' do
        choose 'Organization administrator'
      end

      click_create_user!

      user = User.find_by(username: 'bang')
      organization_user = Organizations::OrganizationUser
        .find_by(user_id: user.id)

      expect(organization_user.access_level).to eq('owner')
    end

    context 'when instance has multiple organizations', :js do
      let_it_be(:organization) { create(:organization, name: 'New Organization') }

      before do
        create(:organization_user, organization: organization, user: admin)
      end

      it 'creates user in the selected organization' do
        within_testid 'organization-section' do
          select_from_listbox 'New Organization', from: common_organization.name
        end

        expect { click_create_user! }.to change { organization.users.count }.by(1)
      end
    end

    context 'with new users set to external enabled' do
      context 'with regex to match internal user email address set', :js do
        before do
          stub_application_setting(user_default_external: true)
          stub_application_setting(user_default_internal_regex: '\.internal@')

          visit new_admin_user_path
        end

        it 'automatically unchecks external for matching email' do
          expects_external_to_be_checked
          expects_warning_to_be_hidden

          fill_in 'user_email', with: 'test.internal@domain.ch'

          expects_external_to_be_unchecked
          expects_warning_to_be_shown

          fill_in 'user_email', with: 'test@domain.ch'

          expects_external_to_be_checked
          expects_warning_to_be_hidden

          uncheck 'user_external'

          expects_warning_to_be_hidden
        end

        it 'creates an internal user' do
          user_name = 'tester1'
          fill_in 'user_email', with: 'test.internal@domain.ch'
          fill_in 'user_name', with: 'tester1 name'
          fill_in 'user_username', with: user_name

          expects_external_to_be_unchecked
          expects_warning_to_be_shown

          click_create_user!

          new_user = User.find_by(username: user_name)

          expect(new_user.external).to be_falsy
        end

        def expects_external_to_be_checked
          expect(find('#user_external')).to be_checked
        end

        def expects_external_to_be_unchecked
          expect(find('#user_external')).not_to be_checked
        end

        def expects_warning_to_be_hidden
          expect(find('#warning_external_automatically_set', visible: :all)[:class]).to include 'hidden'
        end

        def expects_warning_to_be_shown
          expect(find('#warning_external_automatically_set')[:class]).not_to include 'hidden'
        end
      end
    end

    def click_create_user!
      click_button 'Create user'

      # Wait for UI element to ensure API request completes before proceeding
      expect(page).to have_content('User was successfully created.')
    end
  end
end
