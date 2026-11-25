# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Mcp::Handlers::ServerDiscoverRequest, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }

  subject(:result) { described_class.new({}, nil, user).invoke }

  describe '#invoke' do
    it 'returns the discovery result' do
      expect(result).to eq({
        resultType: 'complete',
        supportedVersions: API::Mcp::Handlers::InitializeRequest::STATELESS_PROTOCOL_VERSIONS,
        capabilities: { tools: { listChanged: false } },
        ttlMs: 300_000,
        cacheScope: 'private',
        _meta: {
          'io.modelcontextprotocol/serverInfo' => { name: 'Official GitLab MCP Server', version: Gitlab::VERSION }
        }
      })
    end

    it 'returns an Integer ttlMs that is not negative' do
      expect(result[:ttlMs]).to be_an(Integer).and be >= 0
    end
  end
end
