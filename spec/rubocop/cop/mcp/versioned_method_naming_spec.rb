# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../rubocop/cop/mcp/versioned_method_naming'

RSpec.describe RuboCop::Cop::Mcp::VersionedMethodNaming, feature_category: :mcp_server do
  it 'flags and corrects a legacy perform method and its call sites' do
    expect_offense(<<~RUBY)
      def perform_0_1_0(arguments)
          ^^^^^^^^^^^^^ Use `perform_v0_1_0`; version dispatch only calls MCP methods with the `v` prefix.
      end

      def perform_default(arguments = {})
        perform_0_1_0(arguments)
        ^^^^^^^^^^^^^ Use `perform_v0_1_0`; version dispatch only calls MCP methods with the `v` prefix.
      end
    RUBY

    expect_correction(<<~RUBY)
      def perform_v0_1_0(arguments)
      end

      def perform_default(arguments = {})
        perform_v0_1_0(arguments)
      end
    RUBY
  end

  it 'flags and corrects a legacy build_variables method' do
    expect_offense(<<~RUBY)
      def build_variables_2_0_0
          ^^^^^^^^^^^^^^^^^^^^^ Use `build_variables_v2_0_0`; version dispatch only calls MCP methods with the `v` prefix.
      end
    RUBY

    expect_correction(<<~RUBY)
      def build_variables_v2_0_0
      end
    RUBY
  end

  it 'flags and corrects a legacy singleton method definition and its self call' do
    expect_offense(<<~RUBY)
      def self.perform_0_1_0(arguments)
               ^^^^^^^^^^^^^ Use `perform_v0_1_0`; version dispatch only calls MCP methods with the `v` prefix.
      end

      self.perform_0_1_0(arguments)
           ^^^^^^^^^^^^^ Use `perform_v0_1_0`; version dispatch only calls MCP methods with the `v` prefix.
    RUBY

    expect_correction(<<~RUBY)
      def self.perform_v0_1_0(arguments)
      end

      self.perform_v0_1_0(arguments)
    RUBY
  end

  it 'flags and corrects a safe-navigation call on self' do
    expect_offense(<<~RUBY)
      self&.perform_0_1_0(arguments)
            ^^^^^^^^^^^^^ Use `perform_v0_1_0`; version dispatch only calls MCP methods with the `v` prefix.
    RUBY

    expect_correction(<<~RUBY)
      self&.perform_v0_1_0(arguments)
    RUBY
  end

  it 'does not flag matching calls on another receiver' do
    expect_no_offenses(<<~RUBY)
      client.perform_0_1_0(arguments)
      client.build_variables_2_0_0(arguments)
    RUBY
  end

  it 'does not flag versioned methods that include the v prefix' do
    expect_no_offenses(<<~RUBY)
      def perform_v0_1_0(arguments)
      end

      def build_variables_v2_0_0
      end
    RUBY
  end

  it 'does not flag default or unrelated methods' do
    expect_no_offenses(<<~RUBY)
      def perform_default(arguments)
      end

      def build_variables(arguments)
      end

      def perform_version_0_1_0(arguments)
      end

      def perform_2(arguments)
      end
    RUBY
  end
end
