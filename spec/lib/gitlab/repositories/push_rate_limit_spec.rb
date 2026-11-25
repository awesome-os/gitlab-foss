# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Repositories::PushRateLimit, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:request) { instance_double(ActionDispatch::Request) }

  describe '.enabled?' do
    it 'is true for a project with the feature flag enabled' do
      expect(described_class.enabled?(project)).to be(true)
    end

    it 'is false without a project' do
      expect(described_class.enabled?(nil)).to be(false)
    end

    context 'when the feature flag is disabled for the project' do
      before do
        stub_feature_flags(rate_limit_git_push_per_project: false)
      end

      it 'is false' do
        expect(described_class.enabled?(project)).to be(false)
      end
    end
  end

  describe '.throttled?' do
    subject(:throttled) { described_class.throttled?(request: request, user: user, project: project) }

    it 'counts the push against the project' do
      expect(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
        .with(request, user, :git_push_per_project, scope: { project: project })
        .and_return(true)

      expect(throttled).to be(true)
    end

    context 'when the limit is not enabled for the project' do
      before do
        stub_feature_flags(rate_limit_git_push_per_project: false)
      end

      it 'does not count anything' do
        expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled_request?)

        expect(throttled).to be(false)
      end
    end
  end

  describe '.retry_after' do
    it 'returns the length of the window in seconds' do
      expect(described_class.retry_after).to eq(60)
    end
  end
end
