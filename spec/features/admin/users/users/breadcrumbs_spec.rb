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

  describe 'show breadcrumbs', :js do
    it 'shows the user name or page name as the last breadcrumb on each user page' do
      visit admin_user_path(user)

      check_breadcrumb(user.name)

      visit projects_admin_user_path(user)

      check_breadcrumb(user.name)

      visit keys_admin_user_path(user)

      check_breadcrumb(user.name)

      visit admin_user_impersonation_tokens_path(user)

      check_breadcrumb(user.name)

      visit admin_user_identities_path(user)

      check_breadcrumb(user.name)

      visit new_admin_user_identity_path(user)

      check_breadcrumb('New identity')

      visit admin_user_identities_path(user)

      find('.table').find(:link, 'Edit').click

      check_breadcrumb('Edit')
    end

    def check_breadcrumb(content)
      expect(find_by_testid('breadcrumb-links').find('li:last-of-type')).to have_content(content)
    end
  end
end
