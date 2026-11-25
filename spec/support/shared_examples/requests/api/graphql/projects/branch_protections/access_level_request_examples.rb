# frozen_string_literal: true

RSpec.shared_examples 'a GraphQL query for access levels' do |access_level_kind|
  include GraphqlHelpers

  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:current_user, freeze: false) { create(:user, maintainer_of: project) }

  let(:variables) { { path: project.full_path } }
  let(:fields) { all_graphql_fields_for("#{access_level_kind.to_s.classify}AccessLevel") }
  let(:access_levels) { protected_branch.public_send("#{access_level_kind}_access_levels") }
  let(:access_levels_count) { access_levels.size }
  let(:maintainer_access_level) { access_levels.for_role.first }
  let(:maintainer_access_level_data) { access_levels_data.first }
  let(:branch_rules_data) { graphql_data_at('project', 'branchRules', 'nodes') }
  let(:access_levels_data) do
    branch_rule = branch_rules_data.find { |data| data['name'] == protected_branch.name }
    branch_rule&.dig(
      'branchProtection',
      "#{access_level_kind.to_s.camelize(:lower)}AccessLevels",
      'nodes'
    )
  end

  let(:query) do
    <<~GQL
    query($path: ID!) {
      project(fullPath: $path) {
        branchRules(first: 2) {
          nodes {
            name
            branchProtection {
              #{access_level_kind.to_s.camelize(:lower)}AccessLevels {
                nodes {
                  #{fields}
                }
              }
            }
          }
        }
      }
    }
    GQL
  end

  context 'when request AccessLevel type objects as a guest user' do
    let_it_be(:protected_branch, freeze: false) { create(:protected_branch, project: project) }

    before do
      project.add_guest(current_user)

      post_graphql(query, current_user: current_user, variables: variables)
    end

    it_behaves_like 'a working graphql query'

    it { expect(access_levels_data).not_to be_present }
  end

  context 'when request AccessLevel type objects as a maintainer' do
    let_it_be(:protected_branch, freeze: false) do
      create(:protected_branch, "maintainers_can_#{access_level_kind}", project: project)
    end

    describe 'query' do
      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new do
          post_graphql(query, current_user: current_user, variables: variables)
        end
        expect_graphql_errors_to_be_empty

        create("protected_branch_#{access_level_kind}_access_level", protected_branch: protected_branch)

        expect do
          post_graphql(query, current_user: current_user, variables: variables)
        end.not_to exceed_all_query_limit(control).allow_skip_cache_inconsistency
        expect_graphql_errors_to_be_empty
      end
    end

    describe 'response' do
      before do
        post_graphql(query, current_user: current_user, variables: variables)
      end

      it_behaves_like 'a working graphql query'

      it 'returns all the access level attributes' do
        expect(maintainer_access_level_data['accessLevel']).to eq(maintainer_access_level.access_level)
        expect(maintainer_access_level_data['accessLevelDescription']).to eq(maintainer_access_level.humanize)
        expect(maintainer_access_level_data.dig('group', 'name')).to be_nil
        expect(maintainer_access_level_data.dig('user', 'name')).to be_nil
      end
    end
  end

  describe 'granular PAT authorization' do
    let_it_be(:protected_branch, freeze: false) do
      create(:protected_branch, "maintainers_can_#{access_level_kind}", project: project)
    end

    let(:user) { current_user }
    let(:boundary_object) { project }
    let(:fields) { 'accessLevel' }
    let(:branch_rule_data_path) { [:project, :branch_rules, :nodes, 1] }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }, variables: variables) }

    it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
      [:read_project, :read_branch_rule, :read_protected_branch] do
      let(:skipped_data_path) do
        branch_rule_data_path +
          [:branch_protection, :"#{access_level_kind}_access_levels", :nodes, 0, :access_level]
      end
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field',
      [:read_project, :read_branch_rule] do
      let(:parent_data_path) { branch_rule_data_path }
      let(:field_data_path) { branch_rule_data_path + [:branch_protection] }
    end
  end
end
