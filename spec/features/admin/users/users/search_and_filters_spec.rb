# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Users', feature_category: :user_management do
  include Features::AdminUsersHelpers
  include ListboxHelpers

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

    describe 'search and sort' do
      before_all do
        create(:user, name: 'Foo Bar', last_activity_on: 3.days.ago)
        create(:user, name: 'Foo Baz', last_activity_on: 2.days.ago)
        create(:user, name: 'Dmitriy')
      end

      it 'searches users by name' do
        visit admin_users_path(search_query: 'Foo')

        expect(has_user?(text: 'Foo Bar')).to be(true)
        expect(has_user?(text: 'Foo Baz')).to be(true)
        expect(has_user?(text: 'Dmitriy')).to be(false)
      end

      it 'sorts users by name' do
        visit admin_users_path

        sort_by('Name')

        expect(first_row.text).to include('Dmitriy')
        expect(second_row.text).to include('Foo Bar')
      end

      it 'sorts search results only' do
        visit admin_users_path(search_query: 'Foo')

        sort_by('Name')
        expect(has_user?(text: 'Dmitriy')).to be(false)
        expect(first_row.text).to include('Foo Bar')
        expect(second_row.text).to include('Foo Baz')
      end

      it 'searches with respect of sorting' do
        visit admin_users_path(sort: 'name_asc', search_query: 'Foo')

        expect(first_row.text).to include('Foo Bar')
        expect(second_row.text).to include('Foo Baz')
      end

      it 'sorts users by recent last activity' do
        visit admin_users_path(search_query: 'Foo')

        sort_by('Recent last activity')

        expect(first_row.text).to include('Foo Baz')
        expect(second_row.text).to include('Foo Bar')
      end

      it 'sorts users by oldest last activity' do
        visit admin_users_path(search_query: 'Foo')

        sort_by('Oldest last activity')

        expect(first_row.text).to include('Foo Bar')
        expect(second_row.text).to include('Foo Baz')
      end
    end

    describe 'Two-factor Authentication filters' do
      it 'filters by users who have enabled 2FA' do
        user_2fa = create(:user, :two_factor)

        visit admin_users_path(filter: 'two_factor_enabled')

        expect(has_user?(text: user_2fa.email)).to be(true)
        expect(all_users.length).to be(1)
      end

      it 'filters users who have not enabled 2FA' do
        visit admin_users_path(filter: 'two_factor_disabled')

        expect(has_user?(text: user.email)).to be(true)
        expect(has_user?(text: admin.email)).to be(true)
        expect(all_users.length).to be(3) # user + admin + pre-seeded duo_code_review_bot
      end
    end

    describe 'Pending approval filter' do
      it 'counts users who are pending approval' do
        create_list(:user, 2, :blocked_pending_approval)

        visit admin_users_path(filter: 'blocked_pending_approval')

        expect(all_users.length).to be(2)
      end

      it 'filters by users who are pending approval' do
        blocked_user = create(:user, :blocked_pending_approval)

        visit admin_users_path(filter: 'blocked_pending_approval')

        expect(has_user?(text: blocked_user.email)).to be(true)
        expect(all_users.length).to be(1)
      end
    end

    describe 'Humans filter' do
      it 'filters by human users' do
        bot_user = create(:user, user_type: :alert_bot)
        normal_user = create(:user)

        visit admin_users_path(filter: 'without_bots')

        expect(has_user?(text: bot_user.email)).to be(false)
        expect(has_user?(text: normal_user.email)).to be(true)
      end
    end

    describe 'Bots filter' do
      it 'filters by bot users' do
        bot_user = create(:user, user_type: :alert_bot)
        normal_user = create(:user)

        visit admin_users_path(filter: 'bots')

        expect(has_user?(text: bot_user.email)).to be(true)
        expect(has_user?(text: normal_user.email)).to be(false)
      end
    end
  end

  def first_row
    all_users[0]
  end

  def second_row
    all_users[1]
  end

  def all_users
    page.all('tbody[role="rowgroup"] > tr')
  end

  def sort_by(option)
    within_testid('filtered-search-block') do
      find('.gl-new-dropdown').click
      select_listbox_item(option)
    end
  end
end
