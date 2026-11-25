# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Mcp::Handlers::ServerDiscoverRequest, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }

  let(:version_key) { API::Helpers::Mcp::RequestMeta::PROTOCOL_VERSION_KEY }
  let(:capabilities_key) { API::Helpers::Mcp::RequestMeta::CLIENT_CAPABILITIES_KEY }
  let(:meta) { { version_key => '2026-07-28', capabilities_key => {} } }

  before do
    stub_application_setting(instance_level_ai_beta_features_enabled: true)
  end

  def post_discover(rpc_params = { _meta: meta })
    body = { jsonrpc: '2.0', method: 'server/discover', id: '1' }
    body[:params] = rpc_params unless rpc_params.nil?

    post api('/mcp', user, oauth_access_token: access_token), params: body.to_json,
      headers: { 'Content-Type' => 'application/json' }
  end

  describe 'POST /mcp with server/discover method' do
    context 'when the mcp_server_stateless_protocol flag is on' do
      it 'returns the discovery result', :aggregate_failures do
        post_discover

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({
          'jsonrpc' => '2.0',
          'id' => '1',
          'result' => {
            'resultType' => 'complete',
            'supportedVersions' => API::Mcp::Handlers::InitializeRequest::STATELESS_PROTOCOL_VERSIONS,
            'capabilities' => { 'tools' => { 'listChanged' => false } },
            'ttlMs' => 300_000,
            'cacheScope' => 'private',
            '_meta' => {
              'io.modelcontextprotocol/serverInfo' => {
                'name' => 'Official GitLab MCP Server',
                'version' => Gitlab::VERSION
              }
            }
          }
        })
      end

      context 'with a modern _meta without client capabilities' do
        let(:meta) { { version_key => '2026-07-28' } }

        it 'returns Invalid params', :aggregate_failures do
          post_discover

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32602)
          expect(json_response['error']['data']['params']).to include(capabilities_key)
        end
      end

      context 'with an unknown protocol version' do
        let(:meta) { { version_key => '2099-01-01', capabilities_key => {} } }

        it 'returns Unsupported protocol version', :aggregate_failures do
          post_discover

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32022)
        end
      end
    end

    context 'when the mcp_server_stateless_protocol flag is off' do
      before do
        stub_feature_flags(mcp_server_stateless_protocol: false)
      end

      it 'returns Method not found', :aggregate_failures do
        post_discover

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['error']['code']).to eq(-32601)
      end
    end
  end
end
