# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Wikis::GetWikiPageTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, :public) }
  let_it_be(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: project) }

  let(:params) { { slug: wiki_page_meta.canonical_slug, project_id: project.full_path } }

  subject(:tool) { described_class.new(current_user: user, params: params, access_token: nil) }

  before_all do
    project.add_developer(user)
    group.add_developer(user)
  end

  describe 'versioning' do
    it 'registers version 0.1.0' do
      expect(tool.version).to eq(Mcp::Tools::Concerns::Constants::VERSIONS[:v0_1_0])
    end

    it 'reads the wikiPage root field' do
      expect(tool.operation_name).to eq('wikiPage')
    end
  end

  describe '#build_variables' do
    it 'resolves the project and slug', :aggregate_failures do
      variables = tool.build_variables

      expect(variables[:slug]).to eq(wiki_page_meta.canonical_slug)
      expect(variables[:projectId]).to eq(project.to_global_id.to_s)
      expect(variables).not_to have_key(:namespaceId)
    end

    context 'when group_id is provided' do
      let(:params) { { slug: 'home', group_id: group.full_path } }

      it 'resolves the group', :aggregate_failures do
        variables = tool.build_variables

        expect(variables[:namespaceId]).to eq(group.to_global_id.to_s)
        expect(variables).not_to have_key(:projectId)
      end
    end

    context 'when neither project_id nor group_id is provided' do
      let(:params) { { slug: 'home' } }

      it 'raises an ArgumentError' do
        expect { tool.build_variables }.to raise_error(ArgumentError, /Provide exactly one of/)
      end
    end

    context 'when both project_id and group_id are provided' do
      let(:params) { { slug: 'home', project_id: project.full_path, group_id: group.full_path } }

      it 'raises an ArgumentError rather than silently picking one' do
        expect { tool.build_variables }.to raise_error(ArgumentError, /Provide exactly one of/)
      end
    end
  end

  describe '#group_wikis_supported?' do
    it 'is disabled in FOSS' do
      # EE replaces this method entirely rather than calling super, so walk
      # past the override to exercise the FOSS definition.
      method = described_class.instance_method(:group_wikis_supported?)
      method = method.super_method until method.owner == described_class

      expect(method.bind_call(tool)).to be(false)
    end
  end

  describe '#process_result' do
    def process(result)
      allow(GitlabSchema).to receive(:execute).and_return(result)
      tool.execute
    end

    context 'when the wiki page is found' do
      let(:result) do
        {
          'data' => {
            'wikiPage' => {
              'id' => 'gid://gitlab/WikiPage::Meta/1',
              'title' => 'Home',
              'slug' => 'home',
              'content' => 'Welcome',
              'webUrl' => 'http://localhost/group/project/-/wikis/home'
            }
          }
        }
      end

      it 'returns the page fields without the id', :aggregate_failures do
        processed = process(result)

        expect(processed[:isError]).to be(false)
        expect(processed[:structuredContent]).to eq(
          'title' => 'Home',
          'slug' => 'home',
          'webUrl' => 'http://localhost/group/project/-/wikis/home',
          'content' => 'Welcome',
          'metadata' => {
            'total_lines' => 1,
            'returned_lines' => { 'start' => 1, 'end' => 1 },
            'truncated' => false,
            'size_bytes' => 7
          }
        )
        expect(Gitlab::Json::SafeParser.parse(processed[:content].first[:text])).to eq(processed[:structuredContent])
      end

      context 'when the page is larger than one window' do
        let(:content) { Array.new(5) { |index| "line #{index}\n" }.join }
        let(:params) { super().merge(limit: 2) }

        before do
          result['data']['wikiPage']['content'] = content
        end

        it 'returns the first window and how to fetch the next one', :aggregate_failures do
          payload = process(result)[:structuredContent]

          expect(payload['content']).to eq("line 0\nline 1\n")
          expect(payload['metadata']).to include(
            'total_lines' => 5, 'returned_lines' => { 'start' => 1, 'end' => 2 }, 'truncated' => true
          )
          expect(payload['system_instruction']).to eq(
            'Content truncated. Remaining lines: 3. To view more, call again with {"offset": 2, "limit": 2}.'
          )
        end
      end
    end

    context 'when the wiki page is not found' do
      let(:result) { { 'data' => { 'wikiPage' => nil } } }

      it 'returns an actionable not-found message', :aggregate_failures do
        processed = process(result)

        expect(processed[:isError]).to be(true)
        expect(processed[:content].first[:text]).to include(
          "Wiki page '#{wiki_page_meta.canonical_slug}' not found"
        )
      end
    end

    context 'when result contains errors' do
      let(:result) { { 'errors' => ['Some error occurred'] } }

      it 'returns error response', :aggregate_failures do
        processed = process(result)

        expect(processed[:isError]).to be(true)
        expect(processed[:content].first[:text]).to eq('Some error occurred')
      end
    end
  end

  describe 'integration' do
    it 'executes the query as the current user with the resolved variables' do
      allow(GitlabSchema).to receive(:execute).and_call_original

      tool.execute

      expect(GitlabSchema).to have_received(:execute).with(
        anything,
        variables: hash_including(slug: wiki_page_meta.canonical_slug, projectId: project.to_global_id.to_s),
        context: hash_including(current_user: user)
      )
    end

    it 'returns the wiki page content', :aggregate_failures do
      result = tool.execute

      expect(result[:isError]).to be(false)
      expect(result[:structuredContent]).to include(
        'title' => wiki_page_meta.title,
        'content' => wiki_page_meta.wiki_page.content
      )
    end

    context 'when group wikis are not supported' do
      let(:params) { { slug: 'home', group_id: group.full_path } }

      before do
        allow(tool).to receive(:group_wikis_supported?).and_return(false)
      end

      it 'returns an unavailable message without executing a query', :aggregate_failures do
        expect(GitlabSchema).not_to receive(:execute)

        result = tool.execute

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to eq(
          'Group wikis are not available on this instance. Use project_id to read a project wiki.'
        )
        expect(::Mcp::Tools::Base::Response.error_reason(result)).to eq(:bad_request)
      end
    end
  end
end
