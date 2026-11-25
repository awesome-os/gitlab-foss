# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RemoveDeprecatedSonnet45CodeReviewPins, feature_category: :code_review_workflow do
  let(:organizations)    { table(:organizations) }
  let(:namespaces)       { table(:namespaces) }
  let(:feature_settings) { table(:ai_namespace_feature_settings) }

  let(:organization) { organizations.create!(name: 'org', path: 'org') }

  let(:review_merge_request_dap) { 21 }
  let(:other_feature) { 1 }

  let(:deprecated_refs) do
    %w[
      claude_sonnet_4_5_20250929
      claude_sonnet_4_5_20250929_vertex
      claude_sonnet_4_5_20250929_bedrock
    ]
  end

  let!(:deprecated_pins) do
    deprecated_refs.map { |ref| create_pin(feature: review_merge_request_dap, ref: ref) }
  end

  # A current model pinned to the code-review feature is kept.
  let!(:current_pin) { create_pin(feature: review_merge_request_dap, ref: 'claude_sonnet_5_5_vertex') }

  # A deprecated model pinned to another feature is kept.
  let!(:other_feature_pin) { create_pin(feature: other_feature, ref: 'claude_sonnet_4_5_20250929') }

  def create_group(path)
    namespaces.create!(name: path, path: path, type: 'Group', organization_id: organization.id)
  end

  def create_pin(feature:, ref:)
    group = create_group("group-#{feature}-#{ref.tr('_', '-')}")

    feature_settings.create!(namespace_id: group.id, feature: feature,
      offered_model_ref: ref, offered_model_name: ref)
  end

  describe '#up' do
    it 'removes every deprecated Sonnet 4.5 pin on the code-review feature' do
      expect { migrate! }.to change { feature_settings.count }.from(5).to(2)

      expect(feature_settings.where(id: deprecated_pins.map(&:id))).to be_empty
    end

    it 'keeps current pins on the code-review feature and pins on other features' do
      migrate!

      expect(feature_settings.pluck(:id)).to contain_exactly(current_pin.id, other_feature_pin.id)
    end

    context 'when rows span multiple batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'removes deprecated pins from every batch, including the last open-ended one' do
        expect { migrate! }.to change { feature_settings.count }.from(5).to(2)

        expect(feature_settings.pluck(:id)).to contain_exactly(current_pin.id, other_feature_pin.id)
      end
    end
  end

  describe '#down' do
    it 'is a no-op' do
      migrate!

      expect { schema_migrate_down! }.not_to change { feature_settings.count }
    end
  end
end
