# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildName, feature_category: :continuous_integration do
  it 'belongs to a build through composite keys' do
    is_expected.to belong_to(:build).class_name('Ci::Build')
      .with_query_constraints([:build_id, :partition_id]).with_primary_key([:id, :partition_id])
  end

  describe 'validation' do
    it { is_expected.to validate_presence_of(:build) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe '#name=' do
    it 'truncates name to 255 characters' do
      build_name = described_class.new
      build_name.name = 'A' * 1000
      expect(build_name.name.size).to eq(255)
    end
  end
end
