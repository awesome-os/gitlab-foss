# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting project fork details', feature_category: :source_code_management do
  include GraphqlHelpers
  include ProjectForksHelper

  let_it_be(:project) { create(:project, :public, :repository_private, :repository) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:forked_project) { fork_project(project, current_user, repository: true) }

  let(:ref) { 'feature' }
  let(:queried_project) { forked_project }

  let(:query) do
    graphql_query_for(:project,
      { full_path: queried_project.full_path }, <<~QUERY
      forkDetails(ref: "#{ref}"){
        ahead
        behind
      }
      QUERY
    )
  end

  context 'when a ref is specified' do
    using RSpec::Parameterized::TableSyntax

    where(:ref, :counts) do
      'feature' | { 'ahead' => 1, 'behind' => 29 }
      'v1.1.1' | { 'ahead' => 5, 'behind' => 0 }
      '7b5160f9bb23a3d58a0accdbe89da13b96b1ece9' | { 'ahead' => 9, 'behind' => 0 }
      'non-existent-branch' | { 'ahead' => nil, 'behind' => nil }
    end

    with_them do
      it 'returns fork details' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['project']['forkDetails']).to eq(counts)
      end
    end
  end

  context 'when a project is not a fork' do
    let(:queried_project) { project }

    it 'does not return fork details' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['project']['forkDetails']).to be_nil
    end
  end

  context 'when project source is not visible' do
    it 'does not return fork details' do
      project.team.truncate

      post_graphql(query, current_user: current_user)

      expect(graphql_data['project']['forkDetails']).to be_nil
    end
  end

  context 'when a user cannot read the code' do
    let_it_be(:current_user) { create(:user) }

    before do
      forked_project.update!({
        repository_access_level: 'private',
        merge_requests_access_level: 'private'
      })
    end

    it 'does not return fork details' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['project']['forkDetails']).to be_nil
    end
  end

  context 'with a fine-grained personal access token' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:upstream) { create(:project, :private, :repository, group: group) }
    let_it_be(:user) { create(:user, maintainer_of: group) }
    let_it_be(:fork_namespace) { create(:group, :private, parent: group) }
    let_it_be(:downstream) { fork_project(upstream, user, namespace: fork_namespace, repository: true) }

    let(:queried_project) { downstream }
    let(:boundary_object) { group }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    def token_for(fork_permissions, upstream_permissions)
      additional_scopes = []
      if upstream_permissions.any?
        additional_scopes << { boundary: ::Authz::Boundary.for(upstream), permissions: upstream_permissions }
      end

      create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(downstream), permissions: fork_permissions,
        additional_scopes: additional_scopes)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_project, :read_code]

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_project do
      let(:parent_data_path) { %i[project] }
      let(:field_data_path) { %i[project fork_details] }
    end

    context 'when the token reads the code of the fork and of its upstream' do
      let(:pat) { token_for([:read_project, :read_code], [:read_code]) }

      it 'returns fork details' do
        request

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:project, :fork_details)).to eq('ahead' => 1, 'behind' => 29)
      end
    end

    context 'when the token reads the code of the fork only' do
      let(:pat) { token_for([:read_project, :read_code], []) }

      it 'does not return fork details' do
        request

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:project)).to be_present
        expect(graphql_data_at(:project, :fork_details)).to be_nil
      end
    end

    context 'when the token reads the code of the upstream only' do
      let(:pat) { token_for([:read_project], [:read_code]) }

      it 'does not return fork details' do
        request

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:project)).to be_present
        expect(graphql_data_at(:project, :fork_details)).to be_nil
      end
    end
  end
end
