# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Usage::MetricDefinition, feature_category: :service_ping do
  # rubocop:disable Rails/FindEach -- The all method invoked here is unrelated to the ActiveRecord scope all
  it 'only has valid metric definitions', :aggregate_failures do
    described_class.all.each do |definition|
      validation_errors = definition.validation_errors
      expect(validation_errors).to be_empty, validation_errors.join
    end
  end
  # rubocop:enable Rails/FindEach
end
