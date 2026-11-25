# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::UserProfile::Menus::SettingsMenu, feature_category: :navigation do
  let(:current_user) { build_stubbed(:user) }

  let(:viewed_user) { current_user }
  let(:context) do
    Sidebars::Context.new(current_user: current_user, container: viewed_user, route_is_active: ->(_) { false })
  end

  subject(:menu) { described_class.new(context) }

  before do
    stub_feature_flags(hide_unpinned_sidebar_items: true)
  end

  describe '.enabled_for?' do
    it { expect(described_class.enabled_for?(nil)).to be(false) }
  end

  describe '#render?' do
    it 'renders on the current user\'s own profile' do
      expect(menu.render?).to be(true)
    end

    context 'when viewing another user\'s profile' do
      let(:viewed_user) { build_stubbed(:user) }

      it { expect(menu.render?).to be(false) }

      context 'when the current user is an admin', :enable_admin_mode do
        let(:current_user) { build_stubbed(:admin) }

        it { expect(menu.render?).to be(false) }
      end
    end

    context 'when logged out' do
      let(:current_user) { nil }

      it { expect(menu.render?).to be(false) }
    end

    context 'when hide_unpinned_sidebar_items is disabled' do
      before do
        stub_feature_flags(hide_unpinned_sidebar_items: false)
      end

      it { expect(menu.render?).to be(false) }

      context 'when settings_side_navigation is enabled' do
        before do
          stub_feature_flags(settings_side_navigation: true)
        end

        it 'renders on the current user\'s own profile' do
          expect(menu.render?).to be(true)
        end

        context 'when viewing another user\'s profile' do
          let(:viewed_user) { build_stubbed(:user) }

          it { expect(menu.render?).to be(false) }
        end
      end
    end
  end

  describe '#link' do
    it 'links to the first settings page' do
      expect(menu.link).to eq(Sidebars::UserSettings::Menus::ProfileMenu.new(context).link)
    end

    context 'when no settings page renders' do
      let(:current_user) { nil }

      it { expect(menu.link).to be_nil }
    end
  end

  describe '#serialize_for_super_sidebar' do
    let(:serialized) { menu.serialize_for_super_sidebar }
    let(:items) { serialized[:items] }

    it 'serializes as the settings section', :aggregate_failures do
      expect(serialized).to include(id: 'settings_menu', title: _('Settings'), icon: 'settings')
      expect(serialized[:link]).to eq(items.first[:link])
    end

    it 'qualifies the disclosure title' do
      expect(serialized[:disclosure_title]).to eq(_('User settings'))
    end

    it 'includes the user settings pages, keeping Access as a nested section', :aggregate_failures do
      expect(items.pluck(:id)).to include('profile_menu', 'account_menu', 'access_menu', 'preferences_menu')
      expect(items.find { |item| item[:id] == 'profile_menu' }[:items]).to be_empty
      expect(items.find { |item| item[:id] == 'access_menu' }[:items].pluck(:id))
        .to include(:password_and_authentication, :ssh_keys)
    end

    context 'when a user settings page is the current route' do
      let(:context) do
        Sidebars::Context.new(
          current_user: current_user,
          container: viewed_user,
          route_is_active: ->(routes) { routes == { controller: :ssh_keys } }
        )
      end

      it 'marks the settings section and the nested page as active', :aggregate_failures do
        access = items.find { |item| item[:id] == 'access_menu' }

        expect(serialized[:is_active]).to be(true)
        expect(access[:is_active]).to be(true)
        expect(access[:items].find { |item| item[:id] == :ssh_keys }[:is_active]).to be(true)
      end
    end
  end
end
