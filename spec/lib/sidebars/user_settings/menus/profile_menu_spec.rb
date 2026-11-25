# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::UserSettings::Menus::ProfileMenu, feature_category: :navigation do
  it_behaves_like 'User settings menu',
    link: '/-/user_settings/profile',
    title: _('Profile'),
    icon: 'profile',
    active_routes: { path: 'user_settings/profiles#show' }

  it_behaves_like 'User settings menu #render? method'

  context 'when hide_unpinned_sidebar_items is disabled' do
    let(:context) { Sidebars::Context.new(current_user: build_stubbed(:user), container: nil) }

    before do
      stub_feature_flags(hide_unpinned_sidebar_items: false)
    end

    it 'keeps the Profile title' do
      expect(described_class.new(context).title).to eq(_('Profile'))
    end

    context 'when settings_side_navigation is enabled' do
      before do
        stub_feature_flags(settings_side_navigation: true)
      end

      it 'names the edit action, since it renders in the profile sidebar\'s Settings section' do
        expect(described_class.new(context).title).to eq(s_('UserProfile|Edit profile'))
      end
    end
  end

  context 'when hide_unpinned_sidebar_items is enabled' do
    let(:context) { Sidebars::Context.new(current_user: build_stubbed(:user), container: nil) }

    before do
      stub_feature_flags(hide_unpinned_sidebar_items: true)
    end

    it 'names the edit action, since it renders in the profile settings dropdown' do
      expect(described_class.new(context).title).to eq(s_('UserProfile|Edit profile'))
    end
  end
end
