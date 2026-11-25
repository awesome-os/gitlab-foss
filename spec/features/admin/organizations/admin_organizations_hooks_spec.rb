# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Organizations::Hooks', feature_category: :webhooks do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:user, :organization_owner, organization: organization) }

  let(:hooks_path) { organization_admin_settings_hooks_path(organization) }

  before do
    sign_in(organization_owner)
  end

  describe 'hooks list' do
    it 'lists the organization hooks' do
      hook = create(:system_hook, organization: organization)

      visit hooks_path

      expect(page).to have_content(hook.url)
      expect(page).to have_link('Edit', href: edit_organization_admin_settings_hook_path(organization, hook))
    end

    it 'does not list hooks of another organization' do
      other_hook = create(:system_hook, organization: create(:organization))

      visit hooks_path

      expect(page).to have_no_content(other_hook.url)
    end
  end

  describe 'adding a hook', :js do
    let(:url) { generate(:url) }

    it 'creates the hook in the organization' do
      visit hooks_path

      click_button 'Add new webhook'
      fill_in 'URL', with: url

      expect do
        click_button 'Add webhook'

        expect(page).to have_current_path(hooks_path, ignore_query: true)
        expect(page).to have_content(url)
      end.to change { organization.system_hooks.count }.by(1)
    end
  end

  describe 'updating a hook', :js do
    let_it_be(:hook) { create(:system_hook, organization: organization) }

    let(:new_url) { generate(:url) }

    it 'saves the changes and stays in the organization admin area' do
      visit edit_organization_admin_settings_hook_path(organization, hook)

      fill_in 'URL', with: new_url
      click_button 'Save changes'

      expect(page).to have_content(_('Webhook updated'))
      expect(page).to have_field('URL', with: new_url)
      expect(page).to have_current_path(
        edit_organization_admin_settings_hook_path(organization, hook), ignore_query: true
      )
      expect(page).to have_content('Recent events')
    end
  end

  describe 'removing a hook', :js do
    let(:hook_url) { generate(:url) }
    let!(:hook) { create(:system_hook, url: hook_url, organization: organization) }

    it 'deletes the hook from the list page' do
      visit hooks_path

      accept_gl_confirm(button_text: 'Delete webhook') { click_link 'Delete' }

      expect(page).to have_content('Webhook deleted')
      expect(page).to have_no_content(hook_url)
    end
  end

  describe 'testing a hook', :js do
    let_it_be(:hook) { create(:system_hook, organization: organization) }

    before do
      WebMock.stub_request(:post, hook.url)
    end

    it 'executes the hook from the list page' do
      visit hooks_path

      click_button 'Test'
      click_link 'Push events'

      expect(page).to have_content('Hook executed successfully')
      expect(page).to have_current_path(hooks_path, ignore_query: true)
    end

    it 'executes the hook from the edit page' do
      edit_path = edit_organization_admin_settings_hook_path(organization, hook)
      visit edit_path

      click_button 'Test'
      click_link 'Push events'

      expect(page).to have_content('Hook executed successfully')
      expect(page).to have_current_path(edit_path, ignore_query: true)
    end
  end

  describe 'hook logs' do
    let_it_be(:hook) { create(:system_hook, organization: organization) }
    let_it_be(:hook_log) { create(:web_hook_log, web_hook: hook, internal_error_message: 'some error') }

    let(:edit_path) { edit_organization_admin_settings_hook_path(organization, hook) }
    let(:log_path) { organization_admin_settings_hook_hook_log_path(organization, hook, hook_log) }

    it 'links recent events to the organization-scoped log page' do
      visit edit_path

      expect(page).to have_content('Recent events')
      expect(page).to have_link('View details', href: log_path)
    end

    it 'shows the log details' do
      visit log_path

      expect(page).to have_content("POST #{hook_log.url}")
      expect(page).to have_content(hook_log.internal_error_message)
      expect(page).to have_content('Resend Request')
    end

    it 'resends the request and returns to the edit page' do
      WebMock.stub_request(:post, hook.url)

      visit log_path
      click_link 'Resend Request'

      expect(page).to have_current_path(edit_path, ignore_query: true)
    end

    context 'when the request data is too large' do
      let(:hook_log) { create(:web_hook_log, web_hook: hook, request_data: WebHookLog::OVERSIZE_REQUEST_DATA) }

      it 'disables the resend button' do
        visit log_path

        expect(page).to have_content('Request data is too large')
        expect(page).to have_button('Resend Request', disabled: true)
        expect(page).to have_no_link('Resend Request')
      end
    end
  end
end
