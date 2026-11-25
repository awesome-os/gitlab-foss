# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../rubocop/cop/gitlab/comment_length'

RSpec.describe RuboCop::Cop::Gitlab::CommentLength, feature_category: :tooling do
  it 'flags a comment block with more than 3 lines of prose' do
    expect_offense(<<~RUBY)
      def foo
        # One.
        # Two.
        #
        # Three.
        # Four.
        ^^^^^^^ Comment has 4 lines of prose, more than 3. Keep the why and move the rest to the MR or issue. See https://docs.gitlab.com/development/code_comments/#keep-comments-short
        bar
      end
    RUBY
  end

  it 'allows a comment block with 3 lines of prose' do
    expect_no_offenses(<<~RUBY)
      # One.
      # Two.
      # Three.
      def foo; end
    RUBY
  end

  it 'does not count YARD tag lines, example code, blank lines, directives, or magic comments' do
    expect_no_offenses(<<~RUBY)
      #!/usr/bin/env ruby
      # frozen_string_literal: true
      ##
      # One.
      #
      # @param bar [String]
      # @option opts [Integer] :limit
      # @yield [baz]
      # @yieldparam baz [Integer]
      # @yieldreturn [Boolean]
      # @raise [ArgumentError]
      # @return [void]
      # @see Foo#bar
      # @api private
      # @deprecated Use Foo#baz instead.
      # @overload foo(bar)
      # @!attribute [r] name
      # @note Secondary emails are checked last.
      # @todo https://gitlab.com/gitlab-org/gitlab/-/issues/1
      # @example
      #   foo('bar')
      #
      #   foo('baz')
      # Two.
      # Three.
      # rubocop:disable Style/Foo -- reason
      # rubocop:enable Style/Foo
      # rubocop:todo Style/Bar
      # rubocop:push -Style/Baz
      # rubocop:pop
      # rubocop:next -Style/Qux
      # noinspection RubyResolve -- reason
      def foo(bar, opts); end
    RUBY
  end

  it 'can be disabled from the last line of the comment block' do
    expect_no_offenses(<<~RUBY)
      # One.
      # Two.
      # Three.
      # Four.
      # rubocop:disable Gitlab/CommentLength -- reason
      def foo; end
      # rubocop:enable Gitlab/CommentLength
    RUBY
  end

  it 'counts indented lines below tags other than @example' do
    expect_offense(<<~RUBY)
      # @param bar [String] a description that
      #   wraps onto a second line,
      #   a third line,
      #   a fourth line,
      #   and a fifth line
      ^^^^^^^^^^^^^^^^^^^^ Comment has 4 lines of prose, more than 3.[...]
      def foo(bar); end
    RUBY
  end

  it 'counts indented prose once a prose line ends an @example' do
    expect_offense(<<~RUBY)
      # @example
      #   foo
      # One.
      #   Two.
      #   Three.
      #   Four.
      ^^^^^^^^^ Comment has 4 lines of prose, more than 3.[...]
      def foo; end
    RUBY
  end

  it 'counts misspelled YARD tags as prose' do
    expect_offense(<<~RUBY)
      # @params bar [String]
      # @returns [void]
      # One.
      # Two.
      ^^^^^^ Comment has 4 lines of prose, more than 3.[...]
      def foo; end
    RUBY
  end

  it 'counts prose that ends in a directive' do
    expect_offense(<<~RUBY)
      # One.
      # Two.
      # Three. # rubocop:disable Style/Foo
      # Four.
      ^^^^^^^ Comment has 4 lines of prose, more than 3.[...]
      def foo; end
    RUBY
  end

  it 'counts prose that starts with rubocop: but is not a directive' do
    expect_offense(<<~RUBY)
      # rubocop: One.
      # rubocop:disabled Two.
      # rubocop: Three.
      # rubocop: Four.
      ^^^^^^^^^^^^^^^^ Comment has 4 lines of prose, more than 3.[...]
      def foo; end
    RUBY
  end

  it 'counts each block separately' do
    expect_no_offenses(<<~RUBY)
      # One.
      # Two.
      foo
      # Three.
      # Four.
      bar
    RUBY
  end

  it 'ignores trailing comments' do
    expect_no_offenses(<<~RUBY)
      foo # One.
      foo # Two.
      foo # Three.
      foo # Four.
    RUBY
  end

  it 'exempts the comment block directly above a class or module' do
    expect_no_offenses(<<~RUBY)
      # One.
      # Two.
      # Three.
      # Four.
      module Foo
        # One.
        # Two.
        # Three.
        # Four.
        class Bar; end
      end
    RUBY
  end

  it 'flags a comment block separated from a class by a blank line' do
    expect_offense(<<~RUBY)
      # One.
      # Two.
      # Three.
      # Four.
      ^^^^^^^ Comment has 4 lines of prose, more than 3.[...]

      class Foo; end
    RUBY
  end

  it 'flags a comment block in a file without code' do
    expect_offense(<<~RUBY)
      # One.
      # Two.
      # Three.
      # Four.
      ^^^^^^^ Comment has 4 lines of prose, more than 3.[...]
    RUBY
  end

  it 'flags a comment block inside a class body' do
    expect_offense(<<~RUBY)
      class Foo
        # One.
        # Two.
        # Three.
        # Four.
        ^^^^^^^ Comment has 4 lines of prose, more than 3.[...]
        def bar; end
      end
    RUBY
  end
end
