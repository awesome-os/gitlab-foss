# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting branch protection for a branch rule', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:branch_rule) { create(:protected_branch) }
  let_it_be(:project) { branch_rule.project }

  let(:branch_protection_data) do
    graphql_data_at('project', 'branchRules', 'nodes', 1, 'branchProtection')
  end

  let(:variables) { { path: project.full_path } }

  let(:fields) { all_graphql_fields_for('BranchProtection') }

  let(:query) do
    <<~GQL
    query($path: ID!) {
      project(fullPath: $path) {
        branchRules(first: 2) {
          nodes {
            branchProtection {
              #{fields}
            }
          }
        }
      }
    }
    GQL
  end

  context 'when the user does not have read_protected_branch abilities' do
    before do
      project.add_guest(current_user)
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it_behaves_like 'a working graphql query'

    it { expect(branch_protection_data).not_to be_present }
  end

  context 'when the user does have read_protected_branch abilities' do
    before do
      project.add_maintainer(current_user)
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it_behaves_like 'a working graphql query'

    it 'includes allow_force_push' do
      expect(branch_protection_data['allowForcePush']).to be_in([true, false])
      expect(branch_protection_data['allowForcePush']).to eq(branch_rule.allow_force_push)
    end
  end

  describe 'granular PAT authorization' do
    let_it_be(:user) { create(:user, maintainer_of: project) }

    let(:boundary_object) { project }
    let(:fields) { 'allowForcePush' }
    let(:branch_rule_data_path) { [:project, :branch_rules, :nodes, 1] }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }, variables: variables) }

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_project, :read_branch_rule, :read_protected_branch]

    it_behaves_like 'denying a granular token that only authorizes the parent of a field',
      [:read_project, :read_branch_rule] do
      let(:parent_data_path) { branch_rule_data_path }
      let(:field_data_path) { branch_rule_data_path + [:branch_protection] }
    end

    context 'when a granular token reads the branch rule and its protection' do
      let(:pat) do
        create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(project),
          permissions: %w[read_project read_branch_rule read_protected_branch])
      end

      it 'returns the branch protection', :aggregate_failures do
        request

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(*branch_rule_data_path, :branch_protection, :allow_force_push))
          .to eq(branch_rule.allow_force_push)
      end
    end
  end
end
