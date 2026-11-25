# frozen_string_literal: true

module Sidebars
  module UserSettings
    module Menus
      class ProfileMenu < ::Sidebars::Menu
        include ::Sidebars::Concerns::RenderIfLoggedIn

        override :link
        def link
          user_settings_profile_path
        end

        override :title
        def title
          # Under either flag this menu only renders in the profile sidebar's Settings
          # section, next to the user's profile, so it needs to name the action.
          if ::Sidebars::UserProfile::Menus::SettingsMenu.enabled_for?(current_user)
            s_('UserProfile|Edit profile')
          else
            _('Profile')
          end
        end

        override :sprite_icon
        def sprite_icon
          'profile'
        end

        override :active_routes
        def active_routes
          { path: 'user_settings/profiles#show' }
        end
      end
    end
  end
end
