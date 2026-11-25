# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the container tag protection rules linked to a project', :aggregate_failures, feature_category: :container_registry do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { project.owner }

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_nodes(:containerProtectionTagRules, of: 'ContainerProtectionTagRule')
    )
  end

  let(:protection_rules) { graphql_data_at(:project, :containerProtectionTagRules, :nodes) }

  subject(:send_graqhql_query) { post_graphql(query, current_user: user) }

  context 'with authorized user owner' do
    before do
      send_graqhql_query
    end

    context 'with container tag protection rule' do
      let_it_be(:tag_protection_rule) { create(:container_registry_protection_tag_rule, project: project) }

      it_behaves_like 'a working graphql query'

      it 'returns exactly one containersProtectionTagRule' do
        expect(protection_rules.count).to eq 1
      end

      it 'returns all container tag protection rule fields' do
        expect(protection_rules).to include(
          hash_including(
            'tagNamePattern' => tag_protection_rule.tag_name_pattern,
            'minimumAccessLevelForDelete' => 'MAINTAINER',
            'minimumAccessLevelForPush' => 'MAINTAINER'
          )
        )
      end
    end

    context 'without container tag protection rule' do
      it_behaves_like 'a working graphql query'

      it 'returns no containersProtectionTagRule' do
        expect(protection_rules).to be_empty
      end
    end
  end

  context 'with unauthorized user' do
    let_it_be(:user) { create(:user, developer_of: project) }

    before do
      send_graqhql_query
    end

    it_behaves_like 'a working graphql query'

    it 'returns no container tag protection rules' do
      expect(protection_rules).to be_empty
    end
  end

  context 'with a fine-grained personal access token' do
    let_it_be(:tag_protection_rule) { create(:container_registry_protection_tag_rule, project: project) }

    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_nodes(:containerProtectionTagRules,
          'id tagNamePattern userPermissions { destroyContainerRegistryProtectionTagRule }'))
    end

    let(:boundary_object) { project }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_project, :read_container_registry_protection_tag_rule]

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_project do
      let(:parent_data_path) { %i[project] }
      let(:field_data_path) { %i[project containerProtectionTagRules] }
    end

    context 'when the token can read the tag protection rules' do
      let(:pat) do
        create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(project),
          permissions: %w[read_project read_container_registry_protection_tag_rule])
      end

      it 'returns the tag protection rules' do
        request

        expect_graphql_errors_to_be_empty
        expect(protection_rules).to contain_exactly(
          hash_including(
            'tagNamePattern' => tag_protection_rule.tag_name_pattern,
            'userPermissions' => { 'destroyContainerRegistryProtectionTagRule' => true }
          )
        )
      end
    end
  end
end
