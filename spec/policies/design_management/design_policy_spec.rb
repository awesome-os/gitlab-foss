# frozen_string_literal: true

require "spec_helper"

RSpec.describe DesignManagement::DesignPolicy, feature_category: :portfolio_management do
  specify { expect(described_class).to delegate_to(IssuePolicy) }
end
