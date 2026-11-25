# frozen_string_literal: true

module Sidebars # rubocop:disable Gitlab/BoundedContexts -- This has to be named this way
  module UserProfile
    module Menus
      class SettingsMenu < ::Sidebars::Menu
        include Gitlab::Utils::StrongMemoize

        # @param user [User, nil]
        # @return [Boolean] whether the profile sidebar holds the user settings for the user
        def self.enabled_for?(user)
          return false unless user

          ::Feature.enabled?(:hide_unpinned_sidebar_items, user) || ::Feature.enabled?(:settings_side_navigation, user)
        end

        override :render?
        def render?
          return false unless current_user && container == current_user
          return false unless self.class.enabled_for?(current_user)

          settings_panel.render?
        end

        override :link
        def link
          settings_panel.renderable_menus.first&.link
        end

        override :title
        def title
          _('Settings')
        end

        override :disclosure_title
        def disclosure_title
          _('User settings')
        end

        override :sprite_icon
        def sprite_icon
          'settings'
        end

        # @note Sections such as Access keep their child pages so the disclosure
        #   can render them as a headed group.
        override :serialize_items_for_super_sidebar
        def serialize_items_for_super_sidebar
          settings_panel.super_sidebar_menu_items
        end

        private

        def settings_panel
          ::Sidebars::UserSettings::Panel.new(context)
        end
        strong_memoize_attr :settings_panel
      end
    end
  end
end
