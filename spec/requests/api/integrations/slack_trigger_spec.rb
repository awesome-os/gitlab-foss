# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Integrations, feature_category: :integrations do # rubocop:disable RSpec/SpecFilePathFormat -- split from integrations_spec.rb by topic
  describe 'POST /slack/trigger' do
    before do
      stub_application_setting(slack_app_verification_token: 'token')
    end

    it 'returns status 200' do
      post api('/slack/trigger'), params: { token: 'token', text: 'help' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['response_type']).to eq("ephemeral")
    end

    it 'returns status 404 when token is invalid' do
      post api('/slack/trigger'), params: { token: 'invalid', text: 'foo' }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['response_type']).to be_blank
    end

    context 'when the workspace is over the rate limit', :clean_gitlab_redis_rate_limiting do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:slack_app_commands, scope: { slack_workspace: 'T0123ABCDEF' })
          .and_return(true)
      end

      it 'returns an ephemeral error with status 200' do
        post api('/slack/trigger'), params: { token: 'token', text: 'help', team_id: 'T0123ABCDEF' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['response_type']).to eq('ephemeral')
        expect(json_response['text']).to eq(Gitlab::ApplicationRateLimiter.throttled_error_message)
      end
    end
  end
end
