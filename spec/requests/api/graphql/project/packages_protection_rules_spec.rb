# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the packages protection rules linked to a project', :aggregate_failures, feature_category: :package_registry do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { project.owner }

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_nodes(:packagesProtectionRules, of: 'PackagesProtectionRule')
    )
  end

  subject { post_graphql(query, current_user: user) }

  context 'with authorized user owner' do
    before do
      subject
    end

    context 'with package protection rule' do
      let_it_be(:package_protection_rule) { create(:package_protection_rule, project: project) }

      it_behaves_like 'a working graphql query'

      it 'returns only on PackagesProtectionRule' do
        expect(graphql_data_at(:project, :packagesProtectionRules, :nodes).count).to eq 1
      end

      it 'returns all packages protection rule fields' do
        expect(graphql_data_at(:project, :packagesProtectionRules, :nodes)).to include(
          hash_including(
            'packageNamePattern' => package_protection_rule.package_name_pattern,
            'packageType' => 'NPM',
            'minimumAccessLevelForDelete' => 'OWNER',
            'minimumAccessLevelForPush' => 'MAINTAINER'
          )
        )
      end
    end

    context 'without package protection rule' do
      it_behaves_like 'a working graphql query'

      it 'returns no PackagesProtectionRule' do
        expect(graphql_data_at(:project, :packagesProtectionRules, :nodes)).to eq []
      end
    end
  end

  context 'with unauthorized user' do
    let_it_be(:user) { create(:user, developer_of: project) }

    before do
      subject
    end

    it_behaves_like 'a working graphql query'

    it 'returns no package protection rules' do
      expect(graphql_data_at(:project, :packagesProtectionRules, :nodes)).to eq []
    end
  end

  context 'with a fine-grained personal access token' do
    let_it_be(:package_protection_rule) { create(:package_protection_rule, project: project) }

    let(:boundary_object) { project }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_project, :read_package_protection_rule]

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_project do
      let(:parent_data_path) { %i[project] }
      let(:field_data_path) { %i[project packagesProtectionRules] }
    end

    context 'when the token can read packages' do
      let(:pat) do
        create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(project),
          permissions: %w[read_project read_package])
      end

      it 'returns the package protection rules' do
        request

        expect_graphql_errors_to_be_empty
        expect(graphql_data_at(:project, :packagesProtectionRules, :nodes)).to contain_exactly(
          hash_including('packageNamePattern' => package_protection_rule.package_name_pattern)
        )
      end
    end
  end
end
