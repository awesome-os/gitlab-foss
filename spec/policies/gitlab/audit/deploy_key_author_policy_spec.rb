# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Audit::DeployKeyAuthorPolicy, feature_category: :compliance_management do
  it 'inherits its rules from NullAuthorPolicy' do
    expect(described_class.superclass).to eq(Gitlab::Audit::NullAuthorPolicy)
  end
end
