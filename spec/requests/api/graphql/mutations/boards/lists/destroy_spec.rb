# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Boards::Lists::Destroy, feature_category: :planning_views do
  include GraphqlHelpers

  let_it_be_with_reload(:current_user) { create(:user) }

  it_behaves_like 'board lists destroy request' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:board) { create(:board, group: group) }
    let_it_be_with_refind(:list) { create(:list, board: board) }

    let(:variables) do
      {
        list_id: GitlabSchema.id_from_object(list).to_s
      }
    end

    let(:mutation) do
      graphql_mutation(:destroy_board_list, variables)
    end

    let(:mutation_response) { graphql_mutation_response(:destroy_board_list) }
    let(:klass) { List }
  end

  describe 'granular PAT authorization' do
    let(:mutation) { graphql_mutation(:destroy_board_list, { list_id: list.to_global_id.to_s }) }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }

    context 'for a group board' do
      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:delete_issue_board_list, :read_issue_board_list] do
        let_it_be(:group) { create(:group, :private) }
        let_it_be(:list) { create(:list, board: create(:board, group: group)) }
        let_it_be(:user) { create(:user, maintainer_of: group) }

        let(:boundary_object) { group }
      end
    end

    context 'for a project board' do
      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:delete_issue_board_list, :read_issue_board_list] do
        let_it_be(:project) { create(:project, :private) }
        let_it_be(:list) { create(:list, board: create(:board, project: project)) }
        let_it_be(:user) { create(:user, maintainer_of: project) }

        let(:boundary_object) { project }
      end
    end
  end
end
