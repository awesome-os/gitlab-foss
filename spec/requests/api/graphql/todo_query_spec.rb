# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Todo Query', feature_category: :notifications do
  include GraphqlHelpers

  let_it_be(:current_user) { nil }
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project) }

  let_it_be(:todo_owner) { create(:user, developer_of: project) }

  let_it_be(:todo) { create(:todo, user: todo_owner, target: issue) }

  let(:todo_subject) { todo }

  let(:fields) do
    <<~GRAPHQL
      id
      targetType
      target {
        webUrl
        ... on WorkItem {
          id
        }
      }
    GRAPHQL
  end

  let(:query) do
    graphql_query_for(:todo, { id: todo_subject.to_global_id.to_s }, fields)
  end

  subject(:graphql_response) do
    result = GitlabSchema.execute(query, context: { current_user: current_user }).to_h
    graphql_dig_at(result, :data, :todo)
  end

  context 'when requesting user is todo owner' do
    let(:current_user) { todo_owner }

    it { is_expected.to include('id' => todo_subject.to_global_id.to_s) }

    context 'when todo target is WorkItem' do
      let(:work_item) { create(:work_item, :task, project: project) }
      let(:todo_subject) { create(:todo, user: todo_owner, target: work_item, target_type: WorkItem.name) }

      it 'works with a WorkItem target' do
        expect(graphql_response).to include(
          'id' => todo_subject.to_gid.to_s,
          'targetType' => 'WORKITEM',
          'target' => {
            'id' => work_item.to_gid.to_s,
            'webUrl' => Gitlab::UrlBuilder.build(work_item)
          }
        )
      end
    end
  end

  context 'when requesting user is not todo owner' do
    let(:current_user) { create(:user) }

    it { is_expected.to be_nil }
  end

  context 'when unauthenticated' do
    it { is_expected.to be_nil }
  end

  describe 'reviewId field' do
    let_it_be(:review_project) { create(:project, :repository, developers: todo_owner) }
    let_it_be(:merge_request) { create(:merge_request, source_project: review_project) }
    let_it_be(:reviewer) { create(:user, developer_of: review_project) }
    let_it_be(:review) { create(:review, author: reviewer, merge_request: merge_request, project: review_project) }
    let_it_be(:review_todo) do
      create(:todo, :review_submitted, user: todo_owner, author: reviewer, project: review_project,
        target: merge_request)
    end

    let_it_be(:review_note) do
      create(:note_on_merge_request, noteable: merge_request, project: review_project, author: reviewer,
        review: review)
    end

    let_it_be(:other_note) do
      create(:note_on_merge_request, noteable: merge_request, project: review_project, author: reviewer)
    end

    let(:current_user) { todo_owner }
    let(:todo_subject) { review_todo }
    let(:fields) do
      <<~GRAPHQL
        reviewId
        targetEntity {
          ... on MergeRequest {
            notes { nodes { id reviewId } }
          }
        }
      GRAPHQL
    end

    before_all do
      create(:todo_review_link, todo: review_todo, review: review)
    end

    it 'returns the review the to-do was raised for, and marks the notes published in it' do
      expect(graphql_response['reviewId']).to eq(review.to_global_id.to_s)
      expect(graphql_response.dig('targetEntity', 'notes', 'nodes')).to contain_exactly(
        { 'id' => review_note.to_global_id.to_s, 'reviewId' => review.to_global_id.to_s },
        { 'id' => other_note.to_global_id.to_s, 'reviewId' => nil }
      )
    end

    context 'when the to-do was not raised by a review' do
      let(:todo_subject) { todo }

      it 'returns null' do
        expect(graphql_response['reviewId']).to be_nil
      end
    end
  end
end
