# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../rubocop/cop/user_admin'

RSpec.describe RuboCop::Cop::UserAdmin, feature_category: :system_access do
  let(:msg) do
    'Direct calls to `User#admin?` to determine admin status should be avoided as they will not take into account ' \
      'the policies framework and will ignore Admin Mode if enabled. Check the permission that protects the ' \
      'action instead, with `can?` or `Ability.allowed?`.'
  end

  it 'flags a method call' do
    expect_offense(<<~RUBY)
      user.admin?
           ^^^^^^ #{msg}
    RUBY
  end

  it 'flags a method call with safe operator' do
    expect_offense(<<~RUBY)
      user&.admin?
            ^^^^^^ #{msg}
    RUBY
  end
end
