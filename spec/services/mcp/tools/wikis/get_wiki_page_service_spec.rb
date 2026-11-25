# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Wikis::GetWikiPageService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :public) }
  let_it_be(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: project) }

  let_it_be(:arguments) { { slug: wiki_page_meta.canonical_slug, project_id: project.full_path } }

  let(:service) { described_class.new(name: 'get_wiki_page') }
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

    it 'locks the description' do
      expect(described_class.version_metadata('0.1.0')[:description]).to eq(
        'Get a wiki page, including its content, from a GitLab project or group. ' \
          'Identify the container with exactly one of project_id or group_id. For large pages, use offset ' \
          'and limit to read in windows; when the response is partial, system_instruction gives the next offset.'
      )
    end

    it 'has readOnlyHint annotation' do
      expect(service.annotations[:readOnlyHint]).to be(true)
    end
  end

  describe 'input schema' do
    it 'locks the full input schema for version 0.1.0' do
      expect(described_class.version_metadata('0.1.0')[:input_schema]).to eq({
        type: 'object',
        required: %w[slug],
        properties: {
          slug: {
            type: 'string',
            description: 'URL slug of the wiki page.'
          },
          project_id: {
            type: 'string',
            description: 'ID or path of the project. Required if group_id is not provided.'
          },
          group_id: {
            type: 'string',
            description: 'ID or path of the group. Required if project_id is not provided.'
          },
          offset: {
            type: 'integer',
            description: 'Zero-indexed line number to start reading from. ' \
              'Omit to start at the beginning of the page.',
            minimum: 0
          },
          line_byte_offset: {
            type: 'integer',
            description: 'Byte position in the line at offset to start from. ' \
              'Use the value system_instruction gives after a long line is cut.',
            minimum: 0
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of lines to return. The maximum is 2000.',
            minimum: 1,
            maximum: 2000
          }
        }
      })
    end

    it 'rejects unknown arguments' do
      expect(service.input_schema[:additionalProperties]).to be(false)
    end
  end

  describe '#perform_v0_1_0' do
    it 'executes graphql tool with arguments' do
      expect(service).to receive(:execute_graphql_tool).with(arguments)

      service.send(:perform_v0_1_0, arguments)
    end
  end

  describe '#execute' do
    let_it_be(:params) { { arguments: arguments } }

    it 'retrieves the wiki page from the project', :aggregate_failures do
      result = service.execute(request: request, params: params)

      expect(result[:isError]).to be(false)
      expect(result[:structuredContent]).to include('title' => wiki_page_meta.title)
    end

    it 'instantiates the tool with the resolved version and arguments' do
      expect(Mcp::Tools::Wikis::GetWikiPageTool).to receive(:new).with(
        current_user: user,
        params: params[:arguments],
        version: '0.1.0',
        access_token: nil,
        request: request
      ).and_call_original

      service.execute(request: request, params: params)
    end

    context 'when the page is larger than one window' do
      let_it_be(:content) { "#{'a' * 40}\nshort\nlast\n" }
      let_it_be(:long_page) { create(:wiki_page, container: project, content: content) }

      before do
        stub_const('Mcp::Tools::Concerns::LineWindow::MAX_WINDOW_BYTES', 16)
      end

      it 'rebuilds the page when the caller follows each system_instruction', :aggregate_failures do
        arguments = { slug: long_page.slug, project_id: project.full_path, limit: 1 }
        instructions = []
        rebuilt = +''

        loop do
          payload = service.execute(request: request, params: { arguments: arguments })[:structuredContent]
          rebuilt << payload['content']
          break unless payload['system_instruction']

          instructions << payload['system_instruction']
          continuation = Gitlab::Json::SafeParser.parse(payload['system_instruction'][/\{.*\}/])
          arguments = arguments.merge(continuation.symbolize_keys)
        end

        expect(rebuilt).to eq(content)
        expect(instructions).to include(
          a_string_including('{"offset": 0, "line_byte_offset": 16}'),
          a_string_including('{"offset": 1, "limit": 1, "line_byte_offset": 0}')
        )
      end
    end

    context 'when limit is above the maximum' do
      let(:params) { { arguments: arguments.merge(limit: 2001) } }

      it 'rejects the call without running the tool', :aggregate_failures do
        expect(Mcp::Tools::Wikis::GetWikiPageTool).not_to receive(:new)

        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('Validation error', 'limit')
      end
    end

    context 'when current_user is not set' do
      before do
        service.set_cred(current_user: nil)
      end

      it 'returns an error response', :aggregate_failures do
        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('current_user is not set')
      end
    end
  end
end
