# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting push access levels for a branch protection', feature_category: :source_code_management do
  include GraphqlHelpers

  it_behaves_like 'a GraphQL query for access levels', :push

  describe 'granular PAT authorization of the deploy key' do
    let_it_be(:project, freeze: false) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:deploy_key, freeze: false) { create(:deploy_key, user: user) }
    let_it_be(:protected_branch, freeze: false) do
      create(:protected_branch, default_access_level: false, project: project)
    end

    let(:boundary_object) { project }
    let(:access_level_data_path) do
      [:project, :branch_rules, :nodes, 1, :branch_protection, :push_access_levels, :nodes, 0]
    end

    let(:query) do
      <<~GQL
      query {
        project(fullPath: "#{project.full_path}") {
          branchRules(first: 2) {
            nodes {
              branchProtection {
                pushAccessLevels {
                  nodes {
                    accessLevel
                    deployKey { id }
                  }
                }
              }
            }
          }
        }
      }
      GQL
    end

    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    before_all do
      create(:deploy_keys_project, :write_access, project: project, deploy_key: deploy_key)
      create(:protected_branch_push_access_level, protected_branch: protected_branch, deploy_key: deploy_key)
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field',
      [:read_project, :read_branch_rule, :read_protected_branch] do
      let(:parent_data_path) { access_level_data_path }
      let(:field_data_path) { access_level_data_path + [:deploy_key] }
    end

    context 'when the token can also read deploy keys' do
      let(:pat) do
        create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(project),
          permissions: %w[read_project read_branch_rule read_protected_branch read_deploy_key])
      end

      it 'returns the deploy key', :aggregate_failures do
        request

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(*access_level_data_path, :deploy_key, :id)).to eq(deploy_key.to_global_id.to_s)
      end
    end
  end
end
