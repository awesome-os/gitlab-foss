# frozen_string_literal: true

# Requires send_final_store_path_request(extra_headers = {}), a method (not a let)
# that sends one authorized request reaching the final store path authorization.
RSpec.shared_examples 'package final store path authorize rate limit' do
  context 'when over the limit', :clean_gitlab_redis_rate_limiting do
    before do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(:package_final_store_path_authorize, any_args)
        .and_wrap_original { |original, key, **kwargs| original.call(key, **kwargs, threshold: 1) }
    end

    it 'rejects the request with a Retry-After header' do
      send_final_store_path_request
      expect(response).to have_gitlab_http_status(:ok)

      send_final_store_path_request
      expect(response).to have_gitlab_http_status(:too_many_requests)
      expect(response.headers['Retry-After']).to eq(1.minute.to_i)
    end

    context 'with the throttle bypass header' do
      before do
        stub_env('GITLAB_THROTTLE_BYPASS_HEADER', 'Gitlab-Bypass-Rate-Limiting')
      end

      it 'still rejects the request' do
        bypass = { 'Gitlab-Bypass-Rate-Limiting' => '1' }

        send_final_store_path_request(bypass)
        send_final_store_path_request(bypass)

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when the package_final_store_path_authorize_rate_limit flag is disabled' do
      before do
        stub_feature_flags(package_final_store_path_authorize_rate_limit: false)
      end

      it 'logs but does not reject the request' do
        rate_limit_state = []
        allow(::Gitlab::Instrumentation::RateLimitState).to receive(:track).and_wrap_original do |original, *args|
          original.call(*args)
          rate_limit_state = ::Gitlab::Instrumentation::RateLimitState.payload.fetch(:rate_limit_state, [])
        end

        2.times { send_final_store_path_request }

        expect(response).to have_gitlab_http_status(:ok)
        expect(rate_limit_state).to include(
          'applimiter_package_final_store_path_authorize:limit_package_final_store_path_authorizes_by_actor_log:log'
        )
      end
    end
  end
end
