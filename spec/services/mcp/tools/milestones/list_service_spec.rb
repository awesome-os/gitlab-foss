# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Milestones::ListService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:milestone) { create(:milestone, project: project, title: 'v1.0') }

  let(:service) { described_class.new(name: 'list_milestones') }
  let(:request) { Grape::Request.new(Rack::MockRequest.env_for('/api/v4/mcp')) }

  before_all do
    project.add_developer(user)
  end

  before do
    service.set_cred(current_user: user)
  end

  describe 'class configuration' do
    it 'inherits from GraphqlService' do
      expect(described_class.superclass).to eq(Mcp::Tools::Base::GraphqlService)
    end

    it 'registers version 0.1.0' do
      expect(described_class.available_versions).to include('0.1.0')
    end

    it 'is annotated read-only with no destructiveHint' do
      expect(service.annotations).to eq(
        { title: 'List milestones', readOnlyHint: true, idempotentHint: true, openWorldHint: false }
      )
    end

    it 'declares the core toolset' do
      expect(described_class.version_metadata('0.1.0')[:toolset]).to eq(:core)
    end
  end

  describe 'input schema' do
    it 'matches the expected contract' do
      expect(described_class.version_metadata('0.1.0')[:input_schema]).to eq(
        {
          type: 'object',
          required: [],
          properties: {
            url: {
              type: 'string',
              description: 'GitLab URL of the project or group.'
            },
            project_id: {
              type: 'string',
              description: 'ID or full path of the project.'
            },
            group_id: {
              type: 'string',
              description: 'ID or full path of the group.'
            },
            state: {
              type: 'string',
              enum: %w[active closed],
              description: 'Filter milestones by state.'
            },
            search: {
              type: 'string',
              description: 'Search string to filter milestones by title.'
            },
            include_ancestors: {
              type: 'boolean',
              description: 'Include milestones from parent groups. For a project, includes milestones ' \
                "from the project's parent group and its ancestors."
            },
            include_descendants: {
              type: 'boolean',
              description: 'Include milestones from subgroups and their projects. Applies only to a group.'
            },
            first: {
              type: 'integer',
              description: 'Number of milestones to return after the cursor (forward pagination). Max 100.',
              minimum: 1,
              maximum: 100
            },
            after: {
              type: 'string',
              description: 'Cursor for forward pagination of milestones. Use pageInfo.endCursor from a ' \
                'previous response.'
            }
          }
        }
      )
    end
  end

  describe 'schema validation' do
    it 'rejects unknown arguments' do
      expect(service.input_schema[:additionalProperties]).to be(false)
    end

    it 'rejects an invalid state value' do
      result = service.execute(
        request: request, params: { arguments: { project_id: project.full_path, state: 'bogus' } }
      )

      expect(result[:content].first[:text]).to include('Validation error')
    end

    it 'rejects a first value above the maximum' do
      result = service.execute(
        request: request, params: { arguments: { project_id: project.full_path, first: 101 } }
      )

      expect(result[:content].first[:text]).to include('Validation error')
    end

    it 'rejects an unrecognized argument' do
      result = service.execute(
        request: request,
        params: { arguments: { project_id: project.full_path, bogus_arg: 'x' } }
      )

      expect(result[:content].first[:text]).to include('Validation error')
    end
  end

  describe '#graphql_tool_class' do
    it 'returns ListTool class' do
      expect(service.send(:graphql_tool_class)).to eq(Mcp::Tools::Milestones::ListTool)
    end
  end

  describe '#perform_v0_1_0' do
    let(:arguments) { { project_id: project.full_path } }

    it 'executes graphql tool with arguments' do
      expect(service).to receive(:execute_graphql_tool).with(arguments)

      service.send(:perform_v0_1_0, arguments)
    end

    it 'returns result from graphql tool' do
      result = service.send(:perform_v0_1_0, arguments)

      expect(result).to be_a(Hash)
      expect(result[:isError]).to be(false)
      expect(result[:structuredContent]).to be_present
    end
  end

  describe '#execute' do
    let(:params) { { arguments: { project_id: project.full_path } } }

    it 'retrieves milestones from the project' do
      result = service.execute(request: request, params: params)

      expect(result[:isError]).to be(false)
      expect(result[:structuredContent]['nodes']).to include(a_hash_including('title' => 'v1.0'))
    end

    it 'instantiates tool with correct parameters' do
      expect(Mcp::Tools::Milestones::ListTool).to receive(:new).with(
        current_user: user,
        params: params[:arguments],
        version: '0.1.0',
        access_token: nil,
        request: request
      ).and_call_original

      service.execute(request: request, params: params)
    end

    context 'when current_user is not set' do
      before do
        service.set_cred(current_user: nil)
      end

      it 'returns error response' do
        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('current_user is not set')
      end
    end

    context 'when CE edition', unless: Gitlab.ee? do
      # TODO: https://gitlab.com/gitlab-org/gitlab/-/work_items/638819
      it_behaves_like 'an MCP tool that avoids N+1 queries', threshold: 16 do
        let_it_be(:group) { create(:group, developers: user) }
        let_it_be(:group_project) { create(:project, group: group) }

        let(:service) { described_class.new(name: 'list_milestones') }
        let(:arguments) { { group_id: group.full_path, include_descendants: true } }

        before_all do
          create(:milestone, group: group)
        end

        def create_additional_records
          2.times { create(:milestone, project: create(:project, group: group)) }
        end
      end
    end
  end
end
