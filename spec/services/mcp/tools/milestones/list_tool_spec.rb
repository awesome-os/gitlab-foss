# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Milestones::ListTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:milestone) { create(:milestone, project: project, title: 'v1.0') }

  let(:params) { { project_id: project.full_path } }
  let(:tool) { described_class.new(current_user: user, params: params, version: '0.1.0', access_token: nil) }

  before_all do
    project.add_developer(user)
    group.add_developer(user)
  end

  describe 'versioning' do
    it 'registers version 0.1.0' do
      expect(tool.version).to eq(Mcp::Tools::Concerns::Constants::VERSIONS[:v0_1_0])
    end

    it 'has correct operation name for a project' do
      expect(tool.operation_name).to eq('project')
    end

    it 'has correct GraphQL operation' do
      expect(tool.graphql_operation).to include('query mcpListMilestones')
    end

    context 'when listing group milestones' do
      let(:params) { { group_id: group.full_path } }

      it 'has correct operation name' do
        expect(tool.operation_name).to eq('group')
      end
    end
  end

  describe '#build_variables' do
    it 'builds variables from params' do
      variables = tool.build_variables

      expect(variables[:fullPath]).to eq(project.full_path)
      expect(variables[:isProject]).to be(true)
      expect(variables[:first]).to eq(20)
    end

    context 'with filters and pagination set' do
      let(:params) do
        {
          project_id: project.full_path,
          state: 'active',
          search: 'v1',
          include_ancestors: true,
          first: 5,
          after: 'cursor'
        }
      end

      it 'passes them through' do
        variables = tool.build_variables

        expect(variables).to include(
          state: 'active',
          searchTitle: 'v1',
          includeAncestors: true,
          first: 5,
          after: 'cursor'
        )
      end
    end

    describe 'parent identification' do
      context 'when no parent is provided' do
        let(:params) { {} }

        it 'raises an ArgumentError' do
          expect { tool.build_variables }.to raise_error(ArgumentError, /Provide exactly one of/)
        end
      end

      context 'when both url and project_id are provided' do
        let(:params) { { url: project.web_url, project_id: project.id.to_s } }

        it 'raises an ArgumentError rather than silently picking one' do
          expect { tool.build_variables }.to raise_error(ArgumentError, /Provide exactly one of/)
        end
      end

      context 'when both project_id and group_id are provided' do
        let(:params) { { project_id: project.id.to_s, group_id: group.id.to_s } }

        it 'raises an ArgumentError rather than silently picking one' do
          expect { tool.build_variables }.to raise_error(ArgumentError, /Provide exactly one of/)
        end
      end

      context 'with a numeric project ID' do
        let(:params) { { project_id: project.id.to_s } }

        it 'resolves the project from the ID' do
          expect(tool.build_variables[:fullPath]).to eq(project.full_path)
        end
      end

      context 'with a project URL' do
        let(:params) { { url: project.web_url } }

        it 'resolves the project and sets isProject', :aggregate_failures do
          variables = tool.build_variables

          expect(variables[:fullPath]).to eq(project.full_path)
          expect(variables[:isProject]).to be(true)
        end
      end

      context 'with a numeric group ID' do
        let(:params) { { group_id: group.id.to_s } }

        it 'resolves the group and sets isProject to false', :aggregate_failures do
          variables = tool.build_variables

          expect(variables[:fullPath]).to eq(group.full_path)
          expect(variables[:isProject]).to be(false)
        end
      end

      context 'with a group URL' do
        let(:params) { { url: group.web_url } }

        it 'resolves the group and sets isProject to false', :aggregate_failures do
          variables = tool.build_variables

          expect(variables[:fullPath]).to eq(group.full_path)
          expect(variables[:isProject]).to be(false)
        end
      end
    end
  end

  describe '#resource_not_found_error' do
    context 'when listing project milestones' do
      it 'returns an error mentioning the project path' do
        error = tool.send(:resource_not_found_error)

        expect(error[:isError]).to be(true)
        expect(error[:content].first[:text]).to eq('Project not found or inaccessible')
      end
    end

    context 'when listing group milestones' do
      let(:params) { { group_id: group.full_path } }

      it 'returns an error mentioning the group path' do
        error = tool.send(:resource_not_found_error)

        expect(error[:isError]).to be(true)
        expect(error[:content].first[:text]).to eq('Group not found or inaccessible')
      end
    end
  end

  describe 'integration' do
    it 'executes query with correct variables' do
      allow(GitlabSchema).to receive(:execute).and_call_original

      tool.execute

      expect(GitlabSchema).to have_received(:execute).with(
        anything,
        variables: hash_including(fullPath: project.full_path),
        context: hash_including(current_user: user)
      )
    end

    it 'returns milestones data with proper formatting' do
      result = tool.execute

      expect(result[:isError]).to be(false)
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first[:type]).to eq('text')
      expect(result[:structuredContent]).to be_a(Hash)
      expect(result[:structuredContent]).to have_key('pageInfo')
      expect(result[:structuredContent]['nodes'].first).to include('title' => 'v1.0')
    end

    context 'when project does not exist' do
      let(:params) { { project_id: 'non_existing_project' } }

      it 'raises a not found error without calling GraphQL', :aggregate_failures do
        expect(GitlabSchema).not_to receive(:execute)

        expect { tool.execute }.to raise_error(
          Mcp::Tools::Concerns::ResourceFinder::ResourceNotFoundError,
          "Project 'non_existing_project' not found or inaccessible"
        )
      end
    end

    context 'when we list group milestones' do
      let_it_be(:group_milestone) { create(:milestone, group: group, title: 'group-v1') }
      let(:params) { { group_id: group.full_path } }

      it 'returns milestones data with proper formatting' do
        result = tool.execute

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]['nodes']).to include(a_hash_including('title' => 'group-v1'))
      end

      context 'when group does not exist' do
        let(:params) { { group_id: 'non_existing_group' } }

        it 'raises a group not found error with the path' do
          expect { tool.execute }.to raise_error(
            Mcp::Tools::Concerns::ResourceFinder::ResourceNotFoundError,
            "Group 'non_existing_group' not found or inaccessible"
          )
        end
      end
    end

    context 'when the user has no access to a private project' do
      let_it_be(:private_project) { create(:project, :private) }
      let_it_be(:private_milestone) { create(:milestone, project: private_project, title: 'secret-v1') }
      let(:params) { { project_id: private_project.full_path } }

      it 'raises without exposing milestone data', :aggregate_failures do
        expect { tool.execute }.to raise_error(
          Mcp::Tools::Concerns::ResourceFinder::ResourceForbiddenError
        ) { |error| expect(error.message).not_to include('secret-v1') }
      end
    end

    context 'when milestones are restricted on the project' do
      let_it_be(:restricted_project) do
        create(:project, :public, :issues_disabled, :merge_requests_disabled, developers: user)
      end

      let(:params) { { project_id: restricted_project.full_path } }

      it 'returns a not found error instead of a generic one', :aggregate_failures do
        result = tool.execute

        expect(result[:isError]).to be(true)
        expect(result[:reason]).to eq(:not_found)
        expect(result[:content].first[:text]).to eq('Project not found or inaccessible')
      end
    end

    describe 'pagination' do
      let_it_be(:second_milestone) { create(:milestone, project: project, title: 'v2.0') }
      let(:params) { { project_id: project.full_path, first: 1 } }

      it 'returns the next page via the cursor from the previous response', :aggregate_failures do
        first_page = tool.execute
        titles = [first_page[:structuredContent]['nodes'].first['title']]

        expect(first_page[:structuredContent]['pageInfo']['hasNextPage']).to be(true)
        end_cursor = first_page[:structuredContent]['pageInfo']['endCursor']

        second_page_params = params.merge(after: end_cursor)
        second_page_tool = described_class.new(
          current_user: user, params: second_page_params, version: '0.1.0', access_token: nil
        )
        second_page = second_page_tool.execute
        titles << second_page[:structuredContent]['nodes'].first['title']

        expect(second_page[:structuredContent]['pageInfo']['hasNextPage']).to be(false)
        expect(titles).to contain_exactly('v1.0', 'v2.0')
      end
    end

    describe 'state filtering' do
      let_it_be(:closed_milestone) { create(:closed_milestone, project: project, title: 'v0.9') }

      it 'returns only active milestones when state is active' do
        result = described_class.new(
          current_user: user, params: params.merge(state: 'active'), version: '0.1.0', access_token: nil
        ).execute

        titles = result[:structuredContent]['nodes'].map { |node| node['title'] }
        expect(titles).to contain_exactly('v1.0')
      end

      it 'returns only closed milestones when state is closed' do
        result = described_class.new(
          current_user: user, params: params.merge(state: 'closed'), version: '0.1.0', access_token: nil
        ).execute

        titles = result[:structuredContent]['nodes'].map { |node| node['title'] }
        expect(titles).to contain_exactly('v0.9')
      end
    end

    describe 'include_descendants' do
      let_it_be(:subgroup) { create(:group, parent: group, developers: user) }
      let_it_be(:subproject) { create(:project, :public, group: subgroup) }
      let_it_be(:descendant_milestone) { create(:milestone, project: subproject, title: 'descendant-v1') }

      let(:params) { { group_id: group.full_path } }

      it 'excludes descendant milestones by default' do
        result = described_class.new(current_user: user, params: params, version: '0.1.0', access_token: nil).execute

        titles = result[:structuredContent]['nodes'].map { |node| node['title'] }
        expect(titles).not_to include('descendant-v1')
      end

      it 'includes descendant milestones when include_descendants is true' do
        result = described_class.new(
          current_user: user, params: params.merge(include_descendants: true), version: '0.1.0', access_token: nil
        ).execute

        titles = result[:structuredContent]['nodes'].map { |node| node['title'] }
        expect(titles).to include('descendant-v1')
      end
    end
  end
end
