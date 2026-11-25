# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::PolicyStore::Policy do
  def policy_with(lifecycle_state)
    described_class.new(id: 1, organization_id: 1, name: "p", trigger_type: "t", lifecycle_state: lifecycle_state)
  end

  describe "#active?" do
    it "is true only for the active lifecycle state" do
      expect(policy_with(described_class::ACTIVE)).to be_active
      expect(policy_with("disabled")).not_to be_active
    end
  end

  describe "#changed_attribute_names" do
    it "holds what it was built with, empty by default, and stays out of the policy's value", :aggregate_failures do
      unchanged = policy_with("active")
      renamed = described_class.new(
        id: 1, organization_id: 1, name: "p", trigger_type: "t", changed_attribute_names: [:name]
      )

      expect(unchanged.changed_attribute_names).to eq([])
      expect(renamed.changed_attribute_names).to eq([:name])
      expect(renamed).to eq(unchanged)
      expect(renamed.to_h).not_to have_key(:changed_attribute_names)
    end
  end
end
