# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update of an existing board list', feature_category: :planning_views do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:board) { create(:board, group: group) }
  let_it_be(:list) { create(:list, board: board, position: 0) }
  let_it_be(:list2) { create(:list, board: board) }
  let_it_be(:input) { { list_id: list.to_global_id.to_s, position: 1, collapsed: true } }

  let(:mutation) { graphql_mutation(:update_board_list, input) }
  let(:mutation_response) { graphql_mutation_response(:update_board_list) }

  it_behaves_like 'a GraphQL request to update board list'

  context 'when the list does not exist' do
    let(:list_id) { "gid://gitlab/List/#{non_existing_record_id}" }
    let(:mutation) { graphql_mutation(:update_board_list, { list_id: list_id, collapsed: true }) }

    it 'returns a top level error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors.first['message']).to eq("No object found for `listId: #{list_id.inspect}`")
    end
  end

  describe 'granular PAT authorization' do
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }

    context 'for a group board' do
      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:update_issue_board_list, :read_issue_board_list] do
        let_it_be(:user) { create(:user, reporter_of: group) }

        let(:boundary_object) { group }
      end
    end

    context 'for a project board' do
      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:update_issue_board_list, :read_issue_board_list] do
        let_it_be(:project) { create(:project, :private) }
        let_it_be(:project_list) { create(:list, board: create(:board, project: project)) }
        let_it_be(:user) { create(:user, reporter_of: project) }

        let(:boundary_object) { project }
        let(:mutation) do
          graphql_mutation(:update_board_list, { list_id: project_list.to_global_id.to_s, collapsed: true })
        end
      end
    end
  end
end
