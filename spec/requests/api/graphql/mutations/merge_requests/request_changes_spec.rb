# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Requesting changes on a merge request', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let(:current_user) { create(:user) }
  let(:merge_request) { create(:merge_request, reviewers: [current_user]) }
  let(:project) { merge_request.project }

  let(:mutation) do
    variables = {
      project_path: project.full_path,
      iid: merge_request.iid.to_s
    }
    graphql_mutation(
      :merge_request_request_changes,
      variables,
      <<-QL.strip_heredoc
        clientMutationId
        errors
        mergeRequest {
          id
        }
      QL
    )
  end

  def mutation_response
    graphql_mutation_response(:merge_request_request_changes)
  end

  def mutation_errors
    mutation_response['errors']
  end

  before do
    project.add_developer(current_user)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :create_merge_request_review do
    let(:user) { current_user }
    let(:boundary_object) { project }
    let(:mutation) do
      graphql_mutation(
        :merge_request_request_changes,
        { project_path: project.full_path, iid: merge_request.iid.to_s },
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  it 'returns an error if the user is not allowed to update the merge request' do
    post_graphql_mutation(mutation, current_user: create(:user))

    expect(graphql_errors).not_to be_empty
  end

  describe 'when the user is a reviewer' do
    it 'requests changes successfully' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_errors).to be_empty
      expect(mutation_response['mergeRequest']['id']).to be_present
    end

    it 'updates the reviewer state to requested_changes' do
      post_graphql_mutation(mutation, current_user: current_user)

      reviewer = merge_request.merge_request_reviewers.find_by(user_id: current_user.id)
      expect(reviewer.state).to eq('requested_changes')
    end

    it 'creates a system note' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { merge_request.notes.count }.by(1)
    end
  end

  describe 'when the reviewer can review but not update the merge request' do
    let(:reporter) { create(:user) }

    before do
      project.add_reporter(reporter)
      merge_request.reviewers << reporter
    end

    it 'reaches the service, which refuses a reviewer who cannot approve', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: reporter)

      expect(graphql_errors).to be_nil
      expect(mutation_errors).to eq(
        [_('You must be able to approve this merge request to request changes.')]
      )
      expect(merge_request.find_reviewer(reporter)).to be_unreviewed
    end
  end

  describe 'when the user is not a reviewer' do
    let(:non_reviewer) { create(:user) }

    before do
      project.add_developer(non_reviewer)
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: non_reviewer)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_errors).to include('Reviewer not found')
    end
  end
end
