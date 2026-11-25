# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../../rubocop/cop/gitlab/authz/use_policy_helpers'

RSpec.describe RuboCop::Cop::Gitlab::Authz::UsePolicyHelpers, feature_category: :permissions do
  it 'does not flag expect_allowed' do
    expect_no_offenses(<<~RUBY)
      expect_allowed(:read_group)
    RUBY
  end

  it 'does not flag expect_disallowed' do
    expect_no_offenses(<<~RUBY)
      expect_disallowed(:read_group)
    RUBY
  end

  it 'flags is_expected.to allow_action(:read_group)' do
    expect_offense(<<~RUBY)
      is_expected.to allow_action(:read_group)
                     ^^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_correction(<<~RUBY)
      expect_allowed(:read_group)
    RUBY
  end

  it 'flags is_expected.not_to allow_action(:pages_multiple_versions)' do
    expect_offense(<<~RUBY)
      is_expected.not_to allow_action(:pages_multiple_versions)
                         ^^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_correction(<<~RUBY)
      expect_disallowed(:pages_multiple_versions)
    RUBY
  end

  it 'flags is_expected.to be_allowed(:read_group)' do
    expect_offense(<<~RUBY)
      is_expected.to be_allowed(:read_group)
                     ^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_correction(<<~RUBY)
      expect_allowed(:read_group)
    RUBY
  end

  it 'flags is_expected.not_to be_allowed(:read_group)' do
    expect_offense(<<~RUBY)
      is_expected.not_to be_allowed(:read_group)
                         ^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_correction(<<~RUBY)
      expect_disallowed(:read_group)
    RUBY
  end

  it 'flags is_expected.to be_disallowed(:read_group)' do
    expect_offense(<<~RUBY)
      is_expected.to be_disallowed(:read_group)
                     ^^^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_correction(<<~RUBY)
      expect_disallowed(:read_group)
    RUBY
  end

  it 'correctly handles multiple permissions' do
    expect_offense(<<~RUBY)
      is_expected.to be_allowed(:admin_epic_relation, :read_epic_relation, :admin_epic_tree_relation)
                     ^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_correction(<<~RUBY)
      expect_allowed(:admin_epic_relation, :read_epic_relation, :admin_epic_tree_relation)
    RUBY
  end

  it 'correctly handles a splat expression' do
    expect_offense(<<~RUBY)
      is_expected.to be_disallowed(*(epic_rules - [:read_epic]))
                     ^^^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_correction(<<~RUBY)
      expect_disallowed(*(epic_rules - [:read_epic]))
    RUBY
  end

  it 'flags but does not autocorrect a conditional matcher' do
    expect_offense(<<~RUBY)
      is_expected.to(allowed ? be_allowed(:read_group) : be_disallowed(:read_group))
                               ^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
                                                         ^^^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_no_corrections
  end

  it 'flags a matcher stored in a where table' do
    expect_offense(<<~RUBY)
      where(:role, :expected_result) do
        :owner     | :be_allowed
                     ^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
        :developer | :be_disallowed
                     ^^^^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
      end
    RUBY
  end

  it 'flags a matcher used as a where table value' do
    expect_offense(<<~RUBY)
      where(:enabled, :matcher) do
        true | be_allowed(:read_group)
               ^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
      end
    RUBY
  end

  it 'flags a matcher picked with public_send' do
    expect_offense(<<~RUBY)
      is_expected.to public_send(allowed ? :be_allowed : :be_disallowed, :read_group)
                                           ^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
                                                         ^^^^^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY
  end

  it 'flags be_banned' do
    expect_offense(<<~RUBY)
      is_expected.to be_banned
                     ^^^^^^^^^ `be_banned` passes for any policy with a `prevent_all` rule. Use `it_behaves_like 'prevent all'` or `'prevent all except'` instead.
    RUBY
  end

  it 'does not flag a conditional with the helpers' do
    expect_no_offenses(<<~RUBY)
      allowed ? expect_allowed(:read_group) : expect_disallowed(:read_group)
    RUBY
  end

  it 'flags but does not autocorrect expect(policy).to be_allowed with explicit receiver' do
    expect_offense(<<~RUBY)
      expect(described_class.new(owner, namespace)).to be_allowed(:read_project)
                                                       ^^^^^^^^^^ Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.
    RUBY

    expect_no_corrections
  end
end
