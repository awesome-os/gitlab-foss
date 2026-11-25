# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::QueryLimiting::UserBudget, :clean_gitlab_redis_rate_limiting, :request_store,
  feature_category: :database do
  let_it_be(:user) { create(:user) }

  let(:usage) { { read_bytes: 1.gigabyte, read_rows: 1_000, duration_s: 1.5 } }

  describe '.enabled?' do
    before do
      allow(Gitlab::Runtime).to receive(:puma?).and_return(true)
    end

    it { expect(described_class.enabled?).to be(true) }

    it 'is false outside puma' do
      allow(Gitlab::Runtime).to receive(:puma?).and_return(false)

      expect(described_class.enabled?).to be(false)
    end

    context 'when click_house_user_query_budget is disabled' do
      before do
        stub_feature_flags(click_house_user_query_budget: false)
      end

      it { expect(described_class.enabled?).to be(false) }
    end
  end

  describe '.exceeded_key' do
    it 'is nil for a fresh user' do
      expect(described_class.exceeded_key(user)).to be_nil
    end

    where(:key) { described_class::KEYS }

    with_them do
      it 'returns the spent budget' do
        limit = Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits.limit_for(key)
        Gitlab::ApplicationRateLimiter.throttled?(key, scope: { user: user }, cost: limit + 1)

        expect(described_class.exceeded_key(user)).to eq(key)
      end
    end

    context 'when enforce_click_house_user_query_budget is disabled' do
      before do
        stub_feature_flags(enforce_click_house_user_query_budget: false)
      end

      it 'only logs a spent budget' do
        Gitlab::ApplicationRateLimiter.throttled?(:click_house_read_rows_by_user, scope: { user: user },
          cost: 3_000_000_001)

        expect(described_class.exceeded_key(user)).to be_nil
      end
    end

    it 'checks Redis once per request' do
      expect(Gitlab::ApplicationRateLimiter).to receive(:peek).exactly(described_class::KEYS.size).times

      2.times { described_class.exceeded_key(user) }
    end
  end

  describe '.check_current_user!' do
    let(:current_user) { user }
    let(:enabled) { true }
    let(:spent_key) { :click_house_read_rows_by_user }

    subject(:check) do
      Gitlab::ApplicationContext.with_context(user: current_user) { described_class.check_current_user! }
    end

    before do
      allow(described_class).to receive_messages(enabled?: enabled, exceeded_key: spent_key)
    end

    it 'raises a rate limit error with Retry-After set to the window' do
      expect { check }.to raise_error(described_class::ExceededError) do |error|
        expect(error).to be_a(RateLimitedService::RateLimitedError)
        expect(error.message).to eq(Gitlab::ApplicationRateLimiter.throttled_error_message)
        expect(error.headers).to eq('Retry-After' => '180')
      end

      expect(described_class).to have_received(:exceeded_key).with(user)
    end

    context 'when the user is under budget' do
      let(:spent_key) { nil }

      it { expect(check).to be_nil }
    end

    context 'when the user no longer exists' do
      let(:current_user) { build_stubbed(:user) }

      it { expect(check).to be_nil }
    end

    context 'without a user' do
      let(:current_user) { nil }

      it { expect(check).to be_nil }
    end

    context 'when the budget is not enabled' do
      let(:enabled) { false }

      it 'does not check the budget' do
        expect(check).to be_nil
        expect(described_class).not_to have_received(:exceeded_key)
      end
    end
  end

  describe '.charge_current_user!' do
    let(:current_user) { user }
    let(:enabled) { true }

    subject(:charge) do
      Gitlab::ApplicationContext.with_context(user: current_user) { described_class.charge_current_user!(**usage) }
    end

    before do
      allow(described_class).to receive(:enabled?).and_return(enabled)
      allow(described_class).to receive(:charge!)
    end

    it 'charges the user of the request' do
      charge

      expect(described_class).to have_received(:charge!).with(user, **usage)
    end

    context 'without a user' do
      let(:current_user) { nil }

      it 'charges nothing' do
        charge

        expect(described_class).not_to have_received(:charge!)
      end
    end

    context 'when the budget is not enabled' do
      let(:enabled) { false }

      it 'charges nothing' do
        charge

        expect(described_class).not_to have_received(:charge!)
      end
    end
  end

  describe '.charge!' do
    it 'charges every budget its usage' do
      described_class::KEYS.zip(usage.values).each do |key, cost|
        expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(key, scope: { user: user }, cost: cost).and_return(false)
      end

      expect(described_class.charge!(user, **usage)).to be_nil
    end

    it 'skips zero costs' do
      expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(:click_house_duration_s_by_user, anything).and_return(false)

      described_class.charge!(user, read_bytes: 0, read_rows: 0, duration_s: 0.1)
    end

    it 'leaves the user under budget after normal usage' do
      described_class.charge!(user, **usage)

      expect(described_class.exceeded_key(user)).to be_nil
    end

    it 'charges every budget even when an earlier one is spent' do
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

      described_class.charge!(user, **usage)

      expect(Gitlab::ApplicationRateLimiter).to have_received(:throttled?).exactly(described_class::KEYS.size).times
    end

    it 'marks the user over budget for the rest of the request once a budget is spent' do
      expect(described_class.exceeded_key(user)).to be_nil

      described_class.charge!(user, **usage, read_rows: 3_000_000_001)

      expect(Gitlab::ApplicationRateLimiter).not_to receive(:peek)
      expect(described_class.exceeded_key(user)).to eq(:click_house_read_rows_by_user)
    end

    it 'stops charging once the request knows the budget is spent' do
      described_class.charge!(user, **usage, read_rows: 3_000_000_001)

      expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)

      described_class.charge!(user, **usage)
    end
  end

  describe 'with an allowlisted user' do
    before do
      allow(Gitlab::RackAttack).to receive(:user_allowlist).and_return(Set.new([user.id]))
      Gitlab::ApplicationRateLimiter.clear_memoization(:gitlab_throttle_user_allowlist)
    end

    after do
      Gitlab::ApplicationRateLimiter.clear_memoization(:gitlab_throttle_user_allowlist)
    end

    it 'never rejects the selects of the user' do
      allow(described_class).to receive(:enabled?).and_return(true)

      Gitlab::ApplicationContext.with_context(user: user) do
        described_class.charge_current_user!(**usage, read_rows: 3_000_000_001)

        expect { described_class.check_current_user! }.not_to raise_error
      end

      expect(described_class.exceeded_key(user)).to be_nil
    end
  end
end
