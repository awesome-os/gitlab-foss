# frozen_string_literal: true

require 'fast_spec_helper'
require 'capybara'
require 'selenium-webdriver'
require 'capybara/selenium/driver'
require 'support/capybara_chrome_clear_storage'

RSpec.describe Capybara::Selenium::Driver::ChromeDriver::ClearStorageWithoutWildcardOrigin, feature_category: :tooling do # rubocop:disable RSpec/SpecFilePathFormat -- support_specs is the conventional location for specs testing spec/support files
  # Stands in for Capybara's ChromeDriver. It records every browser action in one
  # ordered log, and its #reset! sends the `*` origin call like Capybara 3.40.0 does.
  let(:upstream_driver) do
    Class.new do
      attr_reader :log
      attr_accessor :current_url, :history, :storage_types, :script_error

      def initialize
        @log = []
        @current_url = 'http://127.0.0.1:3000/group1'
        @history = []
        @storage_types = 'cookies,local_storage'
        @browser = self
      end

      def reset!
        @log << [:navigate, 'about:blank']
        execute_cdp('Storage.clearDataForOrigin', { origin: '*', storageTypes: storage_types })
      end

      def execute_cdp(cmd, params = {})
        @log << [cmd, params]
        { 'entries' => history.map { |url| { 'url' => url } } } if cmd == 'Page.getNavigationHistory'
      end

      def execute_script(script)
        raise script_error if script_error

        @log << [:script, script]
      end

      def window_handles
        %w[first second]
      end

      def switch_to_window(handle)
        @log << [:switch_to_window, handle]
      end

      def unhandled_alert_errors
        []
      end

      prepend Capybara::Selenium::Driver::ChromeDriver::ClearStorageWithoutWildcardOrigin
    end
  end

  subject(:driver) { upstream_driver.new }

  def actions(name)
    driver.log.select { |action, _| action == name }
  end

  def local_storage_origins
    actions('Storage.clearDataForOrigin').map { |_, params| params[:origin] }
  end

  it 'is prepended to the real ChromeDriver' do
    expect(Capybara::Selenium::Driver::ChromeDriver.ancestors).to include(described_class)
  end

  # Fails when Capybara stops sending the `*` origin, which means this override can go.
  it 'overrides the storage call that Capybara ChromeDriver#reset! sends' do
    file, = Capybara::Selenium::Driver::ChromeDriver.instance_method(:reset!).super_method.source_location

    expect(File.read(file)).to include("execute_cdp('Storage.clearDataForOrigin', origin: '*'")
  end

  describe '#reset!' do
    before do
      driver.history = ['http://127.0.0.1:3000/group1']
    end

    it 'clears every kind of storage, session storage first while the page is still open' do
      driver.reset!

      expect(driver.log).to eq([
        [:switch_to_window, 'first'],
        [:script, 'window.sessionStorage.clear()'],
        [:navigate, 'about:blank'],
        ['Network.clearBrowserCookies', {}],
        ['Page.getNavigationHistory', {}],
        ['Storage.clearDataForOrigin', { origin: 'http://127.0.0.1:3000', storageTypes: 'local_storage' }]
      ])
    end

    it 'never sends the `*` origin to Chrome' do
      driver.reset!

      expect(actions('Storage.clearDataForOrigin')).to all(satisfy { |_, params| params[:origin] != '*' })
    end
  end

  describe 'clearing session storage' do
    context 'when the window shows a page without web storage' do
      before do
        driver.current_url = 'about:blank'
      end

      it 'skips the clear and still resets' do
        driver.reset!

        expect(actions(:script)).to be_empty
        expect(actions(:navigate)).to be_present
      end
    end

    context 'when the clear fails' do
      before do
        driver.script_error = Selenium::WebDriver::Error::JavascriptError
      end

      it 'still resets' do
        driver.reset!

        expect(actions(:navigate)).to be_present
      end
    end
  end

  describe 'clearing cookies and local storage' do
    context 'when Capybara asks to clear only cookies' do
      before do
        driver.storage_types = 'cookies'
        driver.history = ['http://a.test/']
      end

      it 'clears cookies and leaves local storage alone' do
        driver.reset!

        expect(actions('Network.clearBrowserCookies')).to be_present
        expect(local_storage_origins).to be_empty
      end
    end

    context 'when the tab visited several pages' do
      before do
        driver.history = [
          'about:blank',
          'data:text/html,hello',
          'http://a.test/one',
          'http://a.test/two',
          'http://127.0.0.1:3000/',
          'https://b.test:443/',
          'http://[invalid',
          'https://'
        ]
      end

      it 'clears local storage once for each web origin, with the port only when it is not the default' do
        driver.reset!

        expect(local_storage_origins).to eq(%w[http://a.test http://127.0.0.1:3000 https://b.test])
      end
    end
  end

  it 'passes other CDP calls through unchanged' do
    driver.execute_cdp('Storage.clearDataForOrigin', { origin: 'http://a.test', storageTypes: 'cookies' })

    expect(driver.log).to eq([['Storage.clearDataForOrigin', { origin: 'http://a.test', storageTypes: 'cookies' }]])
  end
end
