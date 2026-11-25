# frozen_string_literal: true

require 'spec_helper'

# SaaS features are left unstubbed, so these hold under FOSS (no EE module) and
# under EE (SaaS gate closed). The rules themselves are covered in the EE spec.
RSpec.describe Gitlab::RateLimit::CostRules, feature_category: :rate_limiting do
  describe '.for_limiter' do
    let(:limiters) { Gitlab::RackAttack::LabkitRateLimit::Limiters }
    let(:registry) { Gitlab::RackAttack::LabkitRateLimit::ThrottleRegistry }

    it 'contributes no rule to any limiter', :aggregate_failures do
      expect(described_class.for_limiter(limiters::COST_BUDGET)).to eq([])
      expect(described_class.for_limiter(registry::GENERAL)).to eq([])
      expect(described_class.for_limiter('unrecognized_limiter')).to eq([])
    end
  end
end
