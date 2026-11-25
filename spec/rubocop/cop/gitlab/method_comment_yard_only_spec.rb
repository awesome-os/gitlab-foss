# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../rubocop/cop/gitlab/method_comment_yard_only'

RSpec.describe RuboCop::Cop::Gitlab::MethodCommentYardOnly, feature_category: :tooling do
  it 'flags prose above a method' do
    expect_offense(<<~RUBY)
      # Finds a user.
      #
      # @param email [String]
      ^^^^^^^^^^^^^^^^^^^^^^^ Use only YARD tags in the comment above a method. [...]
      def find(email); end
    RUBY
  end

  it 'allows YARD tags, their indented continuation lines, directives, and magic comments' do
    expect_no_offenses(<<~RUBY)
      # frozen_string_literal: true
      # @param email [String] a description that
      #   wraps onto a second line
      # @option opts [Integer] :limit
      # @!attribute [r] name
      # @deprecated
      # @since 1.0
      # @!visibility private
      # @note Secondary emails are checked last.
      # @todo https://gitlab.com/gitlab-org/gitlab/-/issues/1
      #
      # @example
      #   find('a@example.com')
      #
      #   find('b@example.com')
      # @return [User, nil]
      # rubocop:disable Style/Foo -- reason
      # noinspection RubyResolve -- reason
      def find(email, opts); end
    RUBY
  end

  it 'flags prose after a YARD tag' do
    expect_offense(<<~RUBY)
      # @param email [String]
      # Falls back to secondary emails.
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use only YARD tags in the comment above a method. [...]
      def find(email); end
    RUBY
  end

  it 'flags prose that ends in a directive' do
    expect_offense(<<~RUBY)
      # Finds a user. # rubocop:disable Style/Foo
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use only YARD tags in the comment above a method. [...]
      def find; end
    RUBY
  end

  it 'flags prose that starts with rubocop: but is not a directive' do
    expect_offense(<<~RUBY)
      # rubocop: Finds a user.
      ^^^^^^^^^^^^^^^^^^^^^^^^ Use only YARD tags in the comment above a method. [...]
      def find; end
    RUBY
  end

  it 'flags a tag in the middle of prose, a misspelled tag, and an indented line without a tag' do
    expect_offense(<<~RUBY)
      # Caches the @return value.
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use only YARD tags in the comment above a method. [...]
      def foo; end

      # @params bar [String]
      ^^^^^^^^^^^^^^^^^^^^^^ Use only YARD tags in the comment above a method. [...]
      def bar; end

      #   Indented prose.
      ^^^^^^^^^^^^^^^^^^^ Use only YARD tags in the comment above a method. [...]
      def baz; end
    RUBY
  end

  it 'flags prose above singleton, modifier, and overridden methods' do
    expect_offense(<<~RUBY)
      class Foo
        # One.
        ^^^^^^ Use only YARD tags in the comment above a method. [...]
        def self.find; end

        # Two.
        ^^^^^^ Use only YARD tags in the comment above a method. [...]
        private def bar; end

        # Three.
        ^^^^^^^^ Use only YARD tags in the comment above a method. [...]
        override :baz
        def baz; end

        override :qux
        # Four.
        ^^^^^^^ Use only YARD tags in the comment above a method. [...]
        def qux; end
      end
    RUBY
  end

  it 'ignores comments that are not directly above a method' do
    expect_no_offenses(<<~RUBY)
      # One.
      class Foo
        # Two.
        BAR = 1

        # Three.

        def baz; end

        qux # Four.
        def quux; end

        corge = 'a
        # Five.'
        def grault; end

        # Six.
        attr_reader :garply
        def waldo; end
      end
    RUBY
  end

  it 'can be disabled from the last line of the comment block' do
    expect_no_offenses(<<~RUBY)
      # One.
      # rubocop:disable Gitlab/MethodCommentYardOnly -- reason
      def find; end
      # rubocop:enable Gitlab/MethodCommentYardOnly
    RUBY
  end
end
