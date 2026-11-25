# frozen_string_literal: true

require 'capybara/selenium/driver'

# Chrome 158 rejects `Storage.clearDataForOrigin` with the `*` origin that
# `ChromeDriver#reset!` sends (Capybara 3.40.0), so every `:js` example fails
# in teardown. This override clears the same storage in two steps of the reset:
#
# 1. Before the upstream reset leaves the test page: session storage. It can
#    only be cleared while the tab still shows its origin.
# 2. When the upstream reset asks to clear the `*` origin, on `about:blank`:
#    cookies, and local storage for each origin the tab visited.
#
# Remove when a Capybara release includes https://github.com/teamcapybara/capybara/issues/2865
module Capybara
  module Selenium
    class Driver
      module ChromeDriver
        module ClearStorageWithoutWildcardOrigin
          WEB_SCHEMES = %w[http https].freeze

          def reset!
            clear_session_storage if @browser
            super
          end

          def execute_cdp(cmd, params = {})
            return super unless cmd == 'Storage.clearDataForOrigin' && params[:origin] == '*'

            clear_cookies_and_local_storage(params[:storageTypes].to_s.split(','))
          end

          private

          # @note Specs rely on this: a dismissed callout, for example, stores a session storage
          #   key that hides the callout in the next example.
          def clear_session_storage
            switch_to_window(window_handles.first)
            return unless origin_of(current_url)

            @browser.execute_script('window.sessionStorage.clear()')
          rescue *unhandled_alert_errors, ::Selenium::WebDriver::Error::WebDriverError
            nil
          end

          def clear_cookies_and_local_storage(storage_types)
            execute_cdp('Network.clearBrowserCookies') if storage_types.include?('cookies')
            return unless storage_types.include?('local_storage')

            visited_origins.each do |origin|
              execute_cdp('Storage.clearDataForOrigin', { origin: origin, storageTypes: 'local_storage' })
            end
          end

          # @note CDP has no call that lists every origin with storage, so this uses the tab
          #   history, like the upstream fix (teamcapybara/capybara#2867).
          def visited_origins
            history = execute_cdp('Page.getNavigationHistory')['entries']
            history.filter_map { |entry| origin_of(entry['url']) }.uniq
          end

          # @return [String, nil] nil for pages without web storage, such as `about:blank`
          def origin_of(url)
            uri = URI.parse(url.to_s)
            return unless WEB_SCHEMES.include?(uri.scheme) && uri.host.to_s != ''

            port = ":#{uri.port}" unless uri.port == uri.default_port
            "#{uri.scheme}://#{uri.host}#{port}"
          rescue URI::InvalidURIError
            nil
          end
        end

        prepend ClearStorageWithoutWildcardOrigin
      end
    end
  end
end
