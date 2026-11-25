# frozen_string_literal: true

module QA
  module Page
    module Profile
      class Menu < Page::Base
        include SubMenus::CreateNewMenu

        def click_ssh_keys
          open_settings_item('SSH keys', section: 'Access')
        end

        def click_account
          open_settings_item('Account')
        end

        def click_emails
          open_settings_item('Emails')
        end

        def click_password_and_authentication
          open_settings_item('Password and authentication', section: 'Access')
        end

        def click_personal_access_tokens
          open_settings_item('Personal access tokens', section: 'Access')
        end

        private

        # @note With the settings_side_navigation feature flag, all user settings are items of one Settings section
        # @param item [String] the sidebar item
        # @param section [String, nil] the section that holds the item without the feature flag
        # @return [void]
        def open_settings_item(item, section: nil)
          wait_for_sidebar_render

          if has_element?('menu-section-button', section_name: 'Settings', wait: 0)
            open_submenu('Settings', item)
          elsif section
            open_submenu(section, item)
          else
            click_element('nav-item-link', submenu_item: item)
          end
        end
      end
    end
  end
end

QA::Page::Profile::Menu.prepend_mod_with('Page::Profile::Menu', namespace: QA)
