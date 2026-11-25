# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::NamespaceVisitsController, feature_category: :navigation do
  describe "POST /" do
    let_it_be(:path) { track_namespace_visits_path }
    let_it_be(:request_params) { nil }

    subject(:request) { post path, params: request_params }

    context "when user is not signed-in" do
      it 'throws an error 302' do
        subject

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    context "when user is signed-in" do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      context "when entity type is not provided" do
        let_it_be(:request_params) { { id: '1' } }

        it 'responds with a code 400' do
          subject

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context "when entity ID is not provided" do
        let_it_be(:request_params) { { type: 'projects' } }

        it 'responds with a code 400' do
          subject

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context "when entity type and ID are provided" do
        let_it_be(:request_params) { { type: 'projects', id: 1 } }

        it 'calls the worker and responds with a code 200' do
          expect(Users::TrackNamespaceVisitsWorker).to receive(:perform_async)

          subject

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when the user is over the rate limit', :freeze_time, :clean_gitlab_redis_rate_limiting do
          let(:limit) { 3 }
          let(:enforce) { true }

          before do
            stub_application_setting(track_namespace_visits_limit: limit)
            stub_feature_flags(enforce_track_namespace_visits_rate_limit: enforce)
            Gitlab::ApplicationRateLimiter.throttled?(:track_namespace_visits, scope: { user: user }, cost: limit)
          end

          context 'when enforce_track_namespace_visits_rate_limit is disabled' do
            let(:enforce) { false }

            it 'logs the request and still calls the worker', :aggregate_failures do
              rate_limit_state = []
              allow(Gitlab::Instrumentation::RateLimitState).to receive(:track).and_wrap_original do |original, *args|
                original.call(*args)
                rate_limit_state = Gitlab::Instrumentation::RateLimitState.payload.fetch(:rate_limit_state, [])
              end
              expect(Users::TrackNamespaceVisitsWorker).to receive(:perform_async)

              subject

              expect(response).to have_gitlab_http_status(:ok)
              expect(rate_limit_state).to include(
                'applimiter_track_namespace_visits:limit_namespace_visit_tracking_by_user_log:log'
              )
            end
          end

          context 'when enforce_track_namespace_visits_rate_limit is enabled' do
            it 'responds with a code 429 and does not call the worker' do
              expect(Users::TrackNamespaceVisitsWorker).not_to receive(:perform_async)

              subject

              expect(response).to have_gitlab_http_status(:too_many_requests)
            end
          end

          context 'when track_namespace_visits_limit is 0' do
            let(:limit) { 0 }

            it 'does not limit the request' do
              expect(Users::TrackNamespaceVisitsWorker).to receive(:perform_async)

              subject

              expect(response).to have_gitlab_http_status(:ok)
            end
          end
        end

        it_behaves_like 'rate limited endpoint', rate_limit_key: :track_namespace_visits do
          let(:current_user) { user }

          def request
            post path, params: request_params
          end

          def request_with_second_scope
            sign_in(create(:user))
            request
          end
        end
      end
    end
  end
end
