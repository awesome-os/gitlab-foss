# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Limit::FieldCallRateLimit::RequestCounter, feature_category: :api do
  subject(:counter) { described_class.new(2) }

  describe '#over_threshold?' do
    it 'is true only once the calls exceed the threshold', :aggregate_failures do
      2.times { counter.count! }

      expect(counter.over_threshold?).to be(false)

      counter.count!

      expect(counter.over_threshold?).to be(true)
    end
  end

  describe '#throttled?' do
    it 'runs the check once and returns its result after that', :aggregate_failures do
      checks = 0
      check = -> do
        checks += 1
        true
      end

      expect(Array.new(2) { counter.throttled?(&check) }).to all(be(true))
      expect(checks).to eq(1)
    end

    it 'remembers a false result' do
      counter.throttled? { false }

      expect(counter.throttled? { true }).to be(false)
    end
  end
end
