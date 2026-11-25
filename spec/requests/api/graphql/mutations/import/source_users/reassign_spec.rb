# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reassign an import source user', feature_category: :importers do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:assignee_user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:import_source_user) { create(:import_source_user, namespace: group) }

  let(:variables) do
    {
      id: import_source_user.to_global_id,
      assignee_user_id: assignee_user.to_global_id
    }
  end

  let(:mutation) do
    graphql_mutation(:import_source_user_reassign, variables) do
      <<~QL
        clientMutationId
        errors
        importSourceUser {
          reassignToUser {
            id
          }
          reassignedByUser {
            id
          }
          status
        }
      QL
    end
  end

  let(:mutation_response) { graphql_mutation_response(:import_source_user_reassign) }

  context 'when user is authorized' do
    before_all do
      group.add_owner(current_user)
    end

    it 'reassign import source user', :aggregate_failures do
      expect(Notify).to receive_message_chain(:import_source_user_reassign, :deliver_later)

      post_graphql_mutation(mutation, current_user: current_user)

      import_source_user = mutation_response['importSourceUser']

      expect(import_source_user['reassignToUser']['id']).to eq(global_id_of(assignee_user).to_s)
      expect(import_source_user['reassignedByUser']['id']).to eq(global_id_of(current_user).to_s)
      expect(import_source_user['status']).to eq('AWAITING_APPROVAL')
    end

    context 'when the reassign fails' do
      let(:assignee_user) { create(:user, :bot) }

      it 'returns the reason and does not change import source user status', :aggregate_failures do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to be_present
        expect(mutation_response['importSourceUser']['status']).to eq('PENDING_REASSIGNMENT')
      end
    end
  end

  context 'when user is not authorized' do
    before_all do
      group.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'with a granular personal access token' do
    let_it_be(:owner) { create(:user, owner_of: group) }

    let(:group_permissions) { [:update_placeholder_reassignment] }
    let(:user_permissions) { [:read_user, :read_import_source_user] }

    let(:pat) do
      user_scope = { boundary: ::Authz::Boundary.for(:user), permissions: assignable_names(user_permissions) }

      create(:granular_pat, user: owner, boundary: ::Authz::Boundary.for(group),
        permissions: assignable_names(group_permissions), additional_scopes: [user_scope])
    end

    def assignable_names(permissions)
      permissions.map { |permission| ::Authz::PermissionGroups::Assignable.preferred_for_permission(permission).name }
    end

    def request
      post_graphql_mutation(mutation, token: { personal_access_token: pat })
    end

    it 'reassigns the import source user and returns it', :aggregate_failures do
      request

      expect_graphql_errors_to_be_empty
      expect(mutation_response['importSourceUser']['reassignToUser']['id']).to eq(global_id_of(assignee_user).to_s)
      expect(mutation_response['importSourceUser']['status']).to eq('AWAITING_APPROVAL')
    end

    context 'when the token cannot update placeholder reassignments in the group' do
      let(:group_permissions) { [] }

      it 'returns an access error and does not reassign', :aggregate_failures do
        request

        expect(graphql_errors).to include(a_hash_including('message' => a_string_including('Access denied')))
        expect(import_source_user.reload.status_name).to eq(:pending_reassignment)
      end
    end

    context 'when the token cannot read users' do
      let(:user_permissions) { [:read_import_source_user] }

      it 'returns an error and does not reassign', :aggregate_failures do
        request

        expect(graphql_errors).to be_present
        expect(import_source_user.reload.status_name).to eq(:pending_reassignment)
      end
    end

    context 'when the token cannot read import source users' do
      let(:user_permissions) { [:read_user] }

      it 'reassigns the import source user without returning it', :aggregate_failures do
        request

        expect_graphql_errors_to_be_empty
        expect(mutation_response['importSourceUser']).to be_nil
        expect(import_source_user.reload.status_name).to eq(:awaiting_approval)
      end
    end
  end
end
