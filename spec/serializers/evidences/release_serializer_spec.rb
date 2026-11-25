# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Evidences::ReleaseSerializer, feature_category: :release_evidence do
  it 'represents an Evidence::ReleaseEntity entity' do
    expect(described_class.entity_class).to eq(Evidences::ReleaseEntity)
  end
end
