# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Timelogs read with a granular token', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :private, :repository, group: group) }
  let_it_be(:user) { create(:user, reporter_of: group) }
  let_it_be(:issue, freeze: false) { create(:issue, project: project) }
  let_it_be(:merge_request, freeze: false) { create(:merge_request, source_project: project) }
  let_it_be(:issue_timelog) { create(:timelog, issue: issue, user: user, time_spent: 600) }
  let_it_be(:merge_request_timelog) do
    create(:merge_request_timelog, merge_request: merge_request, user: user, time_spent: 900)
  end

  let(:boundary_object) { project }
  let(:timelogs) { 'timelogs { nodes { timeSpent userPermissions { adminTimelog } } }' }
  let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

  def post_with_permissions(permissions)
    assignables = Array(permissions).map do |permission|
      ::Authz::PermissionGroups::Assignable.preferred_for_permission(permission).name
    end
    token = create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(boundary_object),
      permissions: assignables)

    post_graphql(query, token: { personal_access_token: token })
  end

  context 'when querying the timelogs of a project from the root' do
    let(:query) do
      graphql_query_for(:timelogs, { project_id: global_id_of(project) },
        'nodes { timeSpent userPermissions { adminTimelog } }')
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :read_timelog
  end

  context 'when querying the timelogs of a group from the root' do
    let(:boundary_object) { group }
    let(:query) { graphql_query_for(:timelogs, { group_id: global_id_of(group) }, 'nodes { timeSpent }') }

    it 'returns the timelogs of its projects to a token with the permission on the group' do
      post_with_permissions(:read_timelog)

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:timelogs, :nodes, :time_spent)).to contain_exactly(600, 900)
    end
  end

  context 'when querying the timelogs of an issue' do
    let(:query) { graphql_query_for(:issue, { id: global_id_of(issue) }, timelogs) }

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_issue, :read_timelog]

    it 'returns the timelogs to a token with both permissions' do
      post_with_permissions([:read_issue, :read_timelog])

      expect(graphql_data_at(:issue, :timelogs, :nodes, :time_spent)).to contain_exactly(600)
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_issue do
      let(:parent_data_path) { %i[issue] }
      let(:field_data_path) { %i[issue timelogs] }
    end
  end

  context 'when querying the timelogs of a merge request' do
    let(:query) { graphql_query_for(:merge_request, { id: global_id_of(merge_request) }, timelogs) }

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_merge_request, :read_timelog]

    it 'returns the timelogs to a token with both permissions' do
      post_with_permissions([:read_merge_request, :read_timelog])

      expect(graphql_data_at(:merge_request, :timelogs, :nodes, :time_spent)).to contain_exactly(900)
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_merge_request do
      let(:parent_data_path) { %i[merge_request] }
      let(:field_data_path) { %i[merge_request timelogs] }
    end
  end

  context 'when querying the timelogs of a project' do
    let(:query) { graphql_query_for(:project, { full_path: project.full_path }, timelogs) }

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_project, :read_timelog]

    it 'returns the timelogs to a token with both permissions' do
      post_with_permissions([:read_project, :read_timelog])

      expect(graphql_data_at(:project, :timelogs, :nodes, :time_spent)).to contain_exactly(600, 900)
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_project do
      let(:parent_data_path) { %i[project] }
      let(:field_data_path) { %i[project timelogs] }
    end
  end

  context 'when querying the timelogs of a work item' do
    let(:query) do
      graphql_query_for(:work_item, { id: "gid://gitlab/WorkItem/#{issue.id}" },
        "features { timeTracking { #{timelogs} } }")
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_work_item, :read_timelog]

    it 'returns the timelogs and their permissions to a token with both permissions' do
      post_with_permissions([:read_work_item, :read_timelog])

      nodes = graphql_data_at(:work_item, :features, :time_tracking, :timelogs, :nodes)
      expect(nodes).to contain_exactly(a_hash_including('timeSpent' => 600, 'userPermissions' => be_present))
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_work_item do
      let(:parent_data_path) { %i[work_item] }
      let(:field_data_path) { %i[work_item features time_tracking timelogs] }
    end
  end
end
