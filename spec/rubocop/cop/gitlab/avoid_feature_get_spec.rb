# frozen_string_literal: true

require 'rubocop_spec_helper'

require_relative '../../../../rubocop/cop/gitlab/avoid_feature_get'

RSpec.describe RuboCop::Cop::Gitlab::AvoidFeatureGet, feature_category: :scalability do
  let(:msg) do
    'Use `stub_feature_flags` method instead of `Feature.get`. See ' \
      'doc/development/feature_flags/index.md#feature-flags-in-tests for more information.'
  end

  it 'bans use of Feature.ban' do
    expect_offense(<<~RUBY)
      Feature.get
              ^^^ #{msg}
      Feature.get(x)
              ^^^ #{msg}
      ::Feature.get
                ^^^ #{msg}
      ::Feature.get(x)
                ^^^ #{msg}
    RUBY
  end

  it 'ignores unrelated code' do
    expect_no_offenses(<<~RUBY)
      Namespace::Feature.get
      Namespace::Feature.get(x)
      Feature.remove(:x)
    RUBY
  end
end
