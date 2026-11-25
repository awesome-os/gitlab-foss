# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting project information', :with_current_organization, feature_category: :system_access do
  include GraphqlHelpers

  let(:fields) do
    <<~GRAPHQL
      name
      namespace { id }
    GRAPHQL
  end

  let(:query) { graphql_query_for('currentUser', {}, fields) }

  subject { graphql_data['currentUser'] }

  before do
    post_graphql(query, current_user: current_user)
  end

  context 'when there is a current_user' do
    let(:organization) { current_organization }
    let(:user_namespace) { create(:user_namespace, organization: organization) }
    let(:current_user) { create(:user, namespace: user_namespace) }

    it_behaves_like 'a working graphql query that returns data'

    it { is_expected.to include('name' => current_user.name, 'namespace' => { 'id' => user_namespace.to_global_id.to_s }) }

    context 'when namespace does not exist for organization' do
      let(:organization) { create(:organization, path: 'random-org-1', name: 'Random org 2') }

      it { is_expected.to include('namespace' => nil) }
    end

    describe 'granular PAT authorization' do
      let(:query) { graphql_query_for('currentUser', {}, 'name') }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :read_user do
        let(:user) { current_user }
        let(:boundary_object) { :user }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type', :read_user do
        let(:user) { current_user }
        let(:boundary_object) { :user }
        let(:query) { graphql_query_for('currentUser', {}, 'userPermissions { createSnippet }') }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
        let(:skipped_data_path) { %i[current_user user_permissions] }
      end

      context 'with the saved replies' do
        let!(:saved_reply) { create(:saved_reply, user: current_user) }
        let(:user) { current_user }
        let(:boundary_object) { :user }
        let(:query) { graphql_query_for('currentUser', {}, 'savedReplies { nodes { id name } }') }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

        it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_user, :read_saved_reply]

        it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_user do
          let(:parent_data_path) { %i[current_user] }
          let(:field_data_path) { %i[current_user saved_replies] }
        end

        context 'when a granular token reads the user and the saved replies' do
          let(:pat) do
            create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(:user),
              permissions: %w[read_user read_saved_reply])
          end

          it 'returns the saved replies', :aggregate_failures do
            request

            expect(graphql_errors).to be_nil
            expect(graphql_data_at(:current_user, :saved_replies, :nodes))
              .to contain_exactly(a_graphql_entity_for(saved_reply, :name))
          end
        end
      end

      context 'with one saved reply' do
        let!(:saved_reply) { create(:saved_reply, user: current_user) }
        let(:user) { current_user }
        let(:boundary_object) { :user }
        let(:query) do
          graphql_query_for('currentUser', {},
            query_graphql_field(:saved_reply, { id: saved_reply.to_global_id.to_s }, 'id name'))
        end

        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

        it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_user do
          let(:parent_data_path) { %i[current_user] }
          let(:field_data_path) { %i[current_user saved_reply] }
        end

        context 'when a granular token reads the user and the saved replies' do
          let(:pat) do
            create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(:user),
              permissions: %w[read_user read_saved_reply])
          end

          it 'returns the saved reply', :aggregate_failures do
            request

            expect(graphql_errors).to be_nil
            expect(graphql_data_at(:current_user, :saved_reply)).to match(a_graphql_entity_for(saved_reply, :name))
          end
        end
      end
    end
  end

  context 'when there is no current_user' do
    let(:current_user) { nil }

    it_behaves_like 'a working graphql query that returns no data'
  end
end
