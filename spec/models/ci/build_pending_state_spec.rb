# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildPendingState, feature_category: :continuous_integration do
  describe 'associations' do
    it 'belongs to a build through composite keys, as the inverse of its pending_state' do
      is_expected.to belong_to(:build).class_name('Ci::Build')
        .with_query_constraints([:build_id, :partition_id]).with_primary_key([:id, :partition_id])
        .inverse_of(:pending_state)
    end
  end

  describe 'validations' do
    subject(:pending_state) { build(:ci_build_pending_state) }

    it { is_expected.to validate_presence_of(:build) }
    it { is_expected.to validate_presence_of(:partition_id) }
  end

  describe '#crc32' do
    context 'when checksum does not exist' do
      let(:pending_state) do
        build(:ci_build_pending_state, trace_checksum: nil)
      end

      it 'returns nil' do
        expect(pending_state.crc32).to be_nil
      end
    end

    context 'when checksum is in hexadecimal' do
      let(:pending_state) do
        build(:ci_build_pending_state, trace_checksum: 'crc32:75bcd15')
      end

      it 'returns decimal representation of the checksum' do
        expect(pending_state.crc32).to eq 123456789
      end
    end
  end

  describe '#set_project_id' do
    it 'sets the project_id before validation' do
      pending_state = create(:ci_build_pending_state)

      expect(pending_state.project_id).to eq(pending_state.build.project_id)
    end

    it 'does not override the project_id if set' do
      existing_project = create(:project)
      pending_state = create(:ci_build_pending_state, project_id: existing_project.id)

      expect(pending_state.project_id).to eq(existing_project.id)
    end
  end
end
