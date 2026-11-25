# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Subscriptions::CoalescePolicy, feature_category: :api do
  describe '.new' do
    it 'rejects a window that is not a positive duration', :aggregate_failures do
      expect { described_class.new(0) }.to raise_error(ArgumentError)
      expect { described_class.new(-1.second) }.to raise_error(ArgumentError)
      expect { described_class.new('1') }.to raise_error(ArgumentError)
    end

    it 'keeps the window' do
      expect(described_class.new(2.seconds).window).to eq(2.seconds)
    end
  end

  describe '#enabled_for?' do
    let(:user) { build_stubbed(:user) }

    subject(:policy) { described_class.new(1.second) }

    it 'follows the feature flag for the user', :aggregate_failures do
      stub_feature_flags(graphql_subscription_coalescing: user)

      expect(policy.enabled_for?(user)).to be(true)
      expect(policy.enabled_for?(build_stubbed(:user))).to be(false)
      expect(policy.enabled_for?(nil)).to be(false)
    end
  end
end
