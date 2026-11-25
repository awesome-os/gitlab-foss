# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Settings side navigation', feature_category: :navigation do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be(:admin) { create(:admin, :with_namespace) }

  let(:current_user) { user }
  let(:menu_id) { 'settings_menu' }
  let(:mount_selector) { '#js-settings-side-nav' }

  before do
    stub_feature_flags(settings_side_navigation: true)
    sign_in(current_user)
  end

  shared_examples 'renders the settings side navigation on settings pages only' do |with_search: true|
    it 'renders it on a settings page' do
      get settings_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to have_css("#{mount_selector}[data-menu-id='#{menu_id}']")
    end

    if with_search
      it 'renders the settings search next to it' do
        get settings_path

        expect(response.body).to have_css('.js-search-settings-app')
      end
    end

    it 'does not render it on other pages' do
      get other_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to have_no_css(mount_selector)
    end

    context 'when settings_side_navigation is disabled' do
      before do
        stub_feature_flags(settings_side_navigation: false)
      end

      it 'does not render it on a settings page' do
        get settings_path

        expect(response.body).to have_no_css(mount_selector)
      end
    end
  end

  context 'with a project' do
    it_behaves_like 'renders the settings side navigation on settings pages only' do
      let(:settings_path) { project_settings_repository_path(project) }
      let(:other_path) { project_path(project) }
    end
  end

  context 'with a group' do
    it_behaves_like 'renders the settings side navigation on settings pages only' do
      let(:settings_path) { edit_group_path(group) }
      let(:other_path) { group_path(group) }
    end
  end

  context 'with the admin area', :enable_admin_mode do
    before do
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    end

    it_behaves_like 'renders the settings side navigation on settings pages only' do
      let(:current_user) { admin }
      let(:menu_id) { 'admin_settings_menu' }
      let(:settings_path) { general_admin_application_settings_path }
      let(:other_path) { admin_root_path }
    end
  end

  context 'with the organization admin area', :without_current_organization do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:organization_owner) { create(:user, :organization_owner, organization: organization) }

    it_behaves_like 'renders the settings side navigation on settings pages only', with_search: false do
      let(:current_user) { organization_owner }
      let(:settings_path) { general_organization_admin_settings_path(organization) }
      let(:other_path) { organization_admin_root_path(organization) }
    end
  end

  context 'with user settings' do
    it_behaves_like 'renders the settings side navigation on settings pages only' do
      let(:settings_path) { user_settings_ssh_keys_path }
      let(:other_path) { user_path(user) }
    end
  end

  context 'with the passkey registration page' do
    # The page stores a WebAuthn user id on the user, so it needs a user that is not frozen.
    let_it_be_with_reload(:passkey_user) { create(:user, :with_namespace) }

    it_behaves_like 'renders the settings side navigation on settings pages only', with_search: false do
      let(:current_user) { passkey_user }
      let(:settings_path) { new_profile_passkey_path }
      let(:other_path) { user_path(passkey_user) }
    end
  end
end
