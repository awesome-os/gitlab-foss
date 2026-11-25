# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::RateLimit::RuleDocument, feature_category: :rate_limiting do
  let(:registry) { Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits }
  let(:rack_limiters) do
    Gitlab::RackAttack::LabkitRateLimit::ThrottleRegistry.by_limiter.keys +
      Gitlab::RackAttack::LabkitRateLimit::Limiters::COST_MODE.keys
  end

  describe '.load' do
    subject(:document) { described_class.load }

    it 'declares the rack limiters and the applimiter keys' do
      expect(document.limiter?('rack_request')).to be(true)
      expect(document.limiter?('applimiter_search_rate_limit')).to be(true)
    end

    # A new limiter in code fails here until its contract entry exists.
    it 'declares every limiter the application builds' do
      names = registry.rules.keys.map { |key| registry.limiter_name(key) } +
        rack_limiters + [Gitlab::Auth::GitBasicAuthBan::LIMITER_NAME]
      missing = names.reject { |name| document.limiter?(name) }

      expect(missing).to be_empty, "add these limiters to config/rate_limits: #{missing.join(', ')}"
    end

    it 'lists every property the applimiter rules count by' do
      registry.rules.each do |key, rule|
        used = rule.characteristics + [rule.count_distinct].compact
        used << registry::ENFORCED_FACT if registry.staged?(key)
        missing = used - document.available_properties(registry.limiter_name(key))

        expect(missing).to be_empty, "#{key} uses #{missing.join(', ')}, which its contract entry does not list"
      end
    end

    it 'lists every fact ClassifiedRequest exposes for the rack limiters' do
      env = Rack::MockRequest.env_for('/api/v4/projects')
      facts = Gitlab::RackAttack::LabkitRateLimit::ClassifiedRequest.new(env).labkit_facts.keys

      rack_limiters.each do |name|
        missing = facts - document.available_properties(name)

        expect(missing).to be_empty, "#{name} is missing the facts #{missing.join(', ')}"
      end
    end

    context 'when a contract file is rejected' do
      let(:broken_file) { Tempfile.new(['broken', '.yaml']) }

      before do
        broken_file.write("available_limiters: [\n")
        broken_file.flush
        allow(described_class).to receive(:contract_files).and_return([broken_file.path])
      end

      after do
        broken_file.close!
      end

      it 'logs the rejection with its step and returns the empty document' do
        expect(Gitlab::AppLogger).to receive(:error)
          .with(hash_including(message: 'rate_limit_config_rejected', step: :parse))

        expect(document.limiters).to be_empty
      end

      it 'raises from the strict form' do
        expect { described_class.load!(strict: true) }
          .to raise_error(Labkit::RateLimit::Config::Error) { |error| expect(error.step).to eq(:parse) }
      end
    end
  end
end
