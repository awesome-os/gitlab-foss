# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../support/helpers/api_validators_helpers'
require 'grape'

RSpec.describe API::Validations::Validators::NotEmpty, feature_category: :api do
  include ApiValidatorsHelpers

  subject(:validator) { described_class.new(['test'], true, true, scope.new, {}) }

  it 'does not raise a validation error for a non-empty string', :aggregate_failures do
    expect_no_validation_error('test' => 'a')
    expect_no_validation_error('test' => ' ')
  end

  it 'does not raise a validation error when the param is absent, leaving it to the presence validator' do
    expect_no_validation_error({})
  end

  it 'raises a validation error for nil' do
    expect_validation_error('test' => nil)
  end

  it 'raises a validation error for an empty string' do
    expect { validate_test_param!('test' => '') }
      .to raise_error(Grape::Exceptions::Validation) { |error| expect(error.message).to eq('is empty') }
  end
end
