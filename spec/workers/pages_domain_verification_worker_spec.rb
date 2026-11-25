# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PagesDomainVerificationWorker, feature_category: :pages do
  subject(:worker) { described_class.new }

  let(:domain) { create(:pages_domain) }

  it 'deduplicates until executing with a TTL longer than the cron interval' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executing)
    expect(described_class.get_deduplication_options).to include(ttl: 2.hours)
  end

  it 'has a concurrency limit' do
    expect(described_class.get_concurrency_limit).to eq(50)
  end

  it_behaves_like 'an idempotent worker' do
    let(:domain) { create(:pages_domain, :unverified) }
    let(:job_args) { [domain.id] }

    before do
      resolver = instance_double(Resolv::DNS)
      allow(resolver).to receive(:timeouts=)
      allow(resolver).to receive(:getresources)
        .and_return([Resolv::DNS::Resource::IN::TXT.new(domain.keyed_verification_code)])
      allow(Resolv::DNS).to receive(:open).and_yield(resolver)
    end

    it 'verifies the domain and notifies once' do
      allow(Gitlab::AppLogger).to receive(:info)
      expect(Gitlab::AppLogger).to receive(:info).with(/changed state to 'verification_succeeded'/).once

      expect { perform_idempotent_work }.to change { domain.reload.verified? }.from(false).to(true)
    end
  end

  describe '#perform' do
    it 'does nothing if the database is read-only' do
      allow(Gitlab::Database).to receive(:read_only?).and_return(true)
      expect(PagesDomain).not_to receive(:find_by).with(id: domain.id)

      worker.perform(domain.id)
    end

    it 'does nothing for a non-existent domain' do
      domain.destroy!

      expect(VerifyPagesDomainService).not_to receive(:new)

      expect { worker.perform(domain.id) }.not_to raise_error
    end

    it 'delegates to VerifyPagesDomainService' do
      service = double(:service)
      expected_domain = satisfy { |obj| obj == domain }

      expect(VerifyPagesDomainService).to receive(:new).with(expected_domain) { service }
      expect(service).to receive(:execute)

      worker.perform(domain.id)
    end
  end
end
