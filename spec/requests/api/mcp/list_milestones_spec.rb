# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- MCP tools share one endpoint
RSpec.describe API::Mcp, 'list_milestones', :api, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, maintainers: [user]) }
  let_it_be(:milestone) { create(:milestone, project: project, title: 'v1.0') }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }

  before do
    stub_application_setting(instance_level_ai_beta_features_enabled: true, mcp_server_enabled: true)
  end

  def call_tool(arguments)
    post api('/mcp', user, oauth_access_token: access_token), params: {
      jsonrpc: '2.0', method: 'tools/call', id: '1',
      params: { name: 'list_milestones', arguments: arguments }
    }, as: :json

    expect(response).to have_gitlab_http_status(:ok)
    json_response.fetch('result')
  end

  it 'lists milestones for a project' do
    result = call_tool(project_id: project.full_path)

    expect(result['isError']).to be(false)
    expect(result.dig('structuredContent', 'nodes')).to include(a_hash_including('title' => 'v1.0'))
  end

  it 'advertises the tool in the core toolset' do
    post api('/mcp', user, oauth_access_token: access_token),
      params: { jsonrpc: '2.0', method: 'tools/list', id: '1' }

    expect(response).to have_gitlab_http_status(:ok)
    tool = json_response.dig('result', 'tools').find { |t| t['name'] == 'list_milestones' }

    expect(tool).to be_present
    expect(tool.dig('inputSchema', 'required')).to be_empty
  end

  it 'rejects an invalid state value' do
    result = call_tool(project_id: project.full_path, state: 'bogus')

    expect(result['isError']).to be(true)
    expect(result['content'].first['text']).to include('Validation error')
  end

  context 'when the project does not exist' do
    it 'returns a not found error' do
      result = call_tool(project_id: 'does/not-exist')

      expect(result['isError']).to be(true)
      expect(result['content'].first['text']).to include("Project 'does/not-exist' not found or inaccessible")
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
