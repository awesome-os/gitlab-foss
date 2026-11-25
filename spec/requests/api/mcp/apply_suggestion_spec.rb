# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'apply_suggestion', :api, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, maintainers: [user]) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }

  let_it_be(:position, freeze: false) do
    Gitlab::Diff::Position.new(
      old_path: 'files/ruby/popen.rb',
      new_path: 'files/ruby/popen.rb',
      old_line: nil,
      new_line: 9,
      diff_refs: merge_request.diff_refs
    )
  end

  let_it_be(:diff_note) do
    create(:diff_note_on_merge_request, noteable: merge_request, position: position, project: project)
  end

  let_it_be(:suggestion) do
    create(:suggestion,
      note: diff_note,
      from_content: "      raise RuntimeError, \"System commands must be given as an array of strings\"\n",
      to_content: "      raise RuntimeError, 'Explosion'\n      # explosion?")
  end

  before do
    stub_application_setting(instance_level_ai_beta_features_enabled: true, mcp_server_enabled: true)
  end

  def call_tool(name, arguments)
    post api('/mcp', user, oauth_access_token: access_token), params: {
      jsonrpc: '2.0', method: 'tools/call', id: '1', params: { name: name, arguments: arguments }
    }, as: :json

    expect(response).to have_gitlab_http_status(:ok)
    json_response.fetch('result')
  end

  it 'applies a suggestion using the id returned by get_merge_request' do
    notes = call_tool('get_merge_request',
      { project_id: project.full_path, merge_request_iid: merge_request.iid, include: ['notes'] })
    suggestion_id = notes.dig('structuredContent', 'notes', 'nodes')
      .flat_map { |note| note.dig('suggestions', 'nodes') }
      .first['id']

    result = call_tool('apply_suggestion', { id: suggestion_id })

    expect(result['isError']).to be(false)
    expect(suggestion.reload).to be_applied
  end

  context 'when the user cannot apply the suggestion' do
    let_it_be(:reporter) { create(:user, reporter_of: project) }
    let_it_be(:reporter_token) { create(:oauth_access_token, user: reporter, scopes: [:mcp]) }

    it 'returns an error and does not apply the suggestion', :aggregate_failures do
      post api('/mcp', reporter, oauth_access_token: reporter_token), params: {
        jsonrpc: '2.0', method: 'tools/call', id: '1',
        params: { name: 'apply_suggestion', arguments: { id: suggestion.id } }
      }, as: :json

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.dig('result', 'isError')).to be(true)
      expect(json_response.to_json).to include('403 Forbidden')
      expect(suggestion.reload).not_to be_applied
    end
  end

  context 'when the suggestion does not exist' do
    it 'returns an error' do
      result = call_tool('apply_suggestion', { id: non_existing_record_id })

      expect(result['isError']).to be(true)
      expect(result.to_json).to include('Suggestion is not applicable as the suggestion was not found.')
    end
  end

  context 'when the suggestion cannot be applied' do
    let_it_be(:unappliable_suggestion) { create(:suggestion, :unappliable, note: diff_note, relative_order: 1) }

    it 'returns an error and does not apply the suggestion', :aggregate_failures do
      result = call_tool('apply_suggestion', { id: unappliable_suggestion.id })

      expect(result['isError']).to be(true)
      expect(result.to_json).to include("Can't apply as this line was changed in a more recent version.")
      expect(unappliable_suggestion.reload).not_to be_applied
    end
  end

  # `allow_mcp_access_update` covers the PUT verb for this resource, but only routes that are
  # registered MCP tools, so an `mcp`-scoped token must still not reach `batch_apply`.
  describe 'PUT /suggestions/batch_apply with an mcp-scoped token' do
    it 'is rejected, since this route is not a registered mcp tool', :aggregate_failures do
      put api('/suggestions/batch_apply', user, oauth_access_token: access_token), params: { ids: [suggestion.id] }

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(json_response['error']).to eq('insufficient_scope')
      expect(suggestion.reload).not_to be_applied
    end
  end
end
