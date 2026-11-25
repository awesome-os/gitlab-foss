# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'mutation Users::SavedReplies::Update', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let!(:saved_reply) { create(:saved_reply, user: current_user) }

  let(:input) { { id: saved_reply.to_global_id, name: 'New name', content: 'New content' } }

  let(:mutation) { graphql_mutation(:saved_reply_update, input) }
  let(:mutation_response) { graphql_mutation_response(:saved_reply_update) }

  it 'updates the saved reply' do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(mutation_response['errors']).to be_empty
    expect(mutation_response['savedReply']).to include(
      'name' => 'New name',
      'content' => 'New content'
    )
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_saved_reply do
    let(:user) { current_user }
    let(:boundary_object) { :user }
    let(:mutation) { graphql_mutation(:saved_reply_update, input, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  context 'when a granular token updates the saved reply' do
    let(:pat) do
      create(:granular_pat, user: current_user, boundary: ::Authz::Boundary.for(:user),
        permissions: %w[update_saved_reply read_saved_reply])
    end

    it 'returns the saved reply', :aggregate_failures do
      post_graphql_mutation(mutation, token: { personal_access_token: pat })

      expect(graphql_errors).to be_nil
      expect(mutation_response['savedReply']).to include('name' => 'New name', 'content' => 'New content')
    end
  end
end
