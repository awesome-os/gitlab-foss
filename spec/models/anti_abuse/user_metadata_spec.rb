# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::UserMetadata, feature_category: :instance_resiliency do
  let_it_be(:user) { create(:user) }

  let(:key) { :top_level_groups_created_count }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it 'accepts known metrics' do
      expect(build(:abuse_user_metadata, metadata: { top_level_groups_created_count: 1 })).to be_valid
    end

    it 'rejects unknown keys' do
      expect(build(:abuse_user_metadata, metadata: { unknown: 1 })).not_to be_valid
    end
  end

  describe '.metric' do
    it 'returns nil when the user has no record' do
      expect(described_class.metric(user.id, key)).to be_nil
    end

    it 'returns nil when the metric is not set' do
      create(:abuse_user_metadata, user: user)

      expect(described_class.metric(user.id, key)).to be_nil
    end

    it 'returns the stored value' do
      create(:abuse_user_metadata, user: user, metadata: { top_level_groups_created_count: 3 })

      expect(described_class.metric(user.id, key)).to eq(3)
    end

    it 'raises for an unknown metric' do
      expect { described_class.metric(user.id, :unknown) }.to raise_error(ArgumentError, /Unknown abuse metric/)
    end
  end

  describe '.initialize_metric' do
    it 'creates the record when the user has none' do
      described_class.initialize_metric(user.id, key, 2)

      expect(described_class.metric(user.id, key)).to eq(2)
    end

    it 'sets the metric when the record exists without it' do
      create(:abuse_user_metadata, user: user)

      described_class.initialize_metric(user.id, key, 2)

      expect(described_class.metric(user.id, key)).to eq(2)
    end

    it 'does not overwrite a stored value' do
      create(:abuse_user_metadata, user: user, metadata: { top_level_groups_created_count: 5 })

      described_class.initialize_metric(user.id, key, 2)

      expect(described_class.metric(user.id, key)).to eq(5)
    end
  end

  describe '.increment_metric' do
    it 'starts from the initial value when the user has no record' do
      described_class.increment_metric(user.id, key, initial: 2)

      expect(described_class.metric(user.id, key)).to eq(3)
    end

    it 'starts from the initial value when the metric is not set' do
      create(:abuse_user_metadata, user: user)

      described_class.increment_metric(user.id, key, initial: 2)

      expect(described_class.metric(user.id, key)).to eq(3)
    end

    it 'increments a stored value and ignores the initial value' do
      create(:abuse_user_metadata, user: user, metadata: { top_level_groups_created_count: 5 })

      described_class.increment_metric(user.id, key, initial: 2)

      expect(described_class.metric(user.id, key)).to eq(6)
    end
  end

  it 'is deleted with the user' do
    other_user = create(:user)
    create(:abuse_user_metadata, user: other_user)

    expect { other_user.destroy! }.to change { described_class.count }.by(-1)
  end
end
