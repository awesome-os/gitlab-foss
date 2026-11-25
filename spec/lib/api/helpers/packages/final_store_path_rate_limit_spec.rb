# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::Packages::FinalStorePathRateLimit, :clean_gitlab_redis_rate_limiting, feature_category: :package_registry do
  let_it_be(:user) { create(:user) }

  let(:helper) do
    Class.new do
      include API::Helpers::Packages::FinalStorePathRateLimit

      attr_accessor :current_user

      def too_many_requests!(**)
        raise 'throttled'
      end
    end.new
  end

  before do
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
      .and_wrap_original { |original, key, **kwargs| original.call(key, **kwargs, threshold: 1) }
  end

  describe '#check_final_store_path_authorize_rate_limit!' do
    it 'rejects the second call by the same user' do
      helper.current_user = user

      expect { helper.check_final_store_path_authorize_rate_limit! }.not_to raise_error
      expect { helper.check_final_store_path_authorize_rate_limit! }.to raise_error('throttled')
    end

    it 'does not share a counter between a user and a deploy token with the same id' do
      helper.current_user = user
      helper.check_final_store_path_authorize_rate_limit!

      helper.current_user = build_stubbed(:deploy_token, id: user.id)

      expect { helper.check_final_store_path_authorize_rate_limit! }.not_to raise_error
      expect { helper.check_final_store_path_authorize_rate_limit! }.to raise_error('throttled')
    end

    it 'limits to 1,500 a minute' do
      limits = ::Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits

      expect(limits.limit_for(:package_final_store_path_authorize)).to eq(1_500)
      expect(limits.period_for(:package_final_store_path_authorize)).to eq(1.minute)
    end
  end
end
