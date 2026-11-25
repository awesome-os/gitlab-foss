# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query current user todos', feature_category: :source_code_management do
  include GraphqlHelpers
  include DesignManagementTestHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, developers: current_user) }
  let_it_be(:public_project) { create(:project, :public) }
  let_it_be(:unauthorized_project) { create(:project) }
  let_it_be(:commit_todo) { create(:on_commit_todo, user: current_user, project: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:confidential_issue) { create(:issue, :confidential, project: public_project) }
  let_it_be(:issue_todo) { create(:todo, project: project, user: current_user, target: issue) }
  let_it_be(:confidential_issue_todo) { create(:todo, project: project, user: current_user, target: confidential_issue) }
  let_it_be(:merge_request_todo) { create(:todo, project: project, user: current_user, target: create(:merge_request, source_project: project)) }
  let_it_be(:design_todo) { create(:todo, project: project, user: current_user, target: create(:design, issue: issue)) }
  let_it_be(:unauthorized_todo) { create(:todo, user: current_user, project: unauthorized_project, target: create(:issue, project: unauthorized_project)) }

  let(:fields) do
    <<~QUERY
    nodes {
      #{all_graphql_fields_for('todos'.classify, max_depth: 2, excluded: ['productAnalyticsState'])}
    }
    QUERY
  end

  let(:query) do
    graphql_query_for('currentUser', {}, query_graphql_field('todos', {}, fields))
  end

  subject { graphql_data.dig('currentUser', 'todos', 'nodes') }

  before do
    enable_design_management

    post_graphql(query, current_user: current_user)
  end

  it_behaves_like 'a working graphql query that returns data'

  it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_user, :read_todo] do
    let(:user) { current_user }
    let(:boundary_object) { :user }
    let(:fields) { 'nodes { id }' }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end

  it 'contains the expected ids' do
    is_expected.to contain_exactly(
      a_hash_including('id' => commit_todo.to_global_id.to_s),
      a_hash_including('id' => issue_todo.to_global_id.to_s),
      a_hash_including('id' => merge_request_todo.to_global_id.to_s),
      a_hash_including('id' => design_todo.to_global_id.to_s)
    )
  end

  it 'returns Todos for all target types' do
    is_expected.to contain_exactly(
      a_hash_including('targetType' => 'COMMIT'),
      a_hash_including('targetType' => 'ISSUE'),
      a_hash_including('targetType' => 'MERGEREQUEST'),
      a_hash_including('targetType' => 'DESIGN')
    )
  end

  context 'when requesting the count' do
    let(:fields) do
      <<~QUERY
      count
      QUERY
    end

    subject { graphql_data.dig('currentUser', 'todos', 'count') }

    it 'returns the number of to-do items' do
      # We should be expecting 4 todos here because the current user
      # doesn't have access to 2 of them.
      # This behaviour is tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/473762
      # and we'll have to update this expectation once that's resolved.
      is_expected.to eq(6)
    end
  end

  context 'when to-do items have a note' do
    let(:fields) do
      <<~QUERY
      nodes {
        id
        note {
          id
          bodyFirstLineHtml
        }
      }
      QUERY
    end

    def create_note_todos(count)
      Array.new(count) do
        noteable = create(:issue, project: project)
        note = create(:note, project: project, noteable: noteable, author: create(:user))

        create(:todo, project: project, user: current_user, target: noteable, note: note, author: note.author)
      end
    end

    it 'avoids N+1 queries', :request_store do
      create_note_todos(1)
      post_graphql(query, current_user: current_user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, current_user: current_user)
      end

      create_note_todos(3)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      expect(graphql_data.dig('currentUser', 'todos', 'nodes').pluck('note').compact.size).to eq(4)
    end

    context 'when the todos_share_associations_with_note feature flag is disabled' do
      before do
        stub_feature_flags(todos_share_associations_with_note: false)
      end

      it 'returns the same notes, loading their associations per to-do item', :request_store do
        create_note_todos(1)
        post_graphql(query, current_user: current_user)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_note_todos(3)

        expect { post_graphql(query, current_user: current_user) }.to exceed_all_query_limit(control)
        expect(graphql_data.dig('currentUser', 'todos', 'nodes').pluck('note').compact.size).to eq(4)
      end
    end
  end

  context 'when requesting the target entity' do
    let_it_be(:alert_todo) do
      create(:todo, project: project, user: current_user, target: create(:alert_management_alert, project: project))
    end

    let(:fields) do
      <<~QUERY
      nodes {
        id
        targetEntity {
          ... on Issue { id reference webPath }
          ... on MergeRequest { id reference webPath }
          ... on Design { id }
          ... on AlertManagementAlert { id }
        }
      }
      QUERY
    end

    let(:target_entity_ids) { subject.to_h { |node| [node['id'], node.dig('targetEntity', 'id')] } }

    let(:expected_target_entity_ids) do
      [issue_todo, merge_request_todo, design_todo, alert_todo].to_h do |todo|
        [todo.to_global_id.to_s, todo.target.to_global_id.to_s]
      end
    end

    it 'returns the target of each to-do item' do
      expect(target_entity_ids).to include(expected_target_entity_ids)
    end

    it 'does not load the targets again', :request_store do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { post_graphql(query, current_user: current_user) }

      create_list(:issue, 2, project: project).each do |target|
        create(:todo, project: project, user: current_user, target: target)
      end

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
    end

    context 'when graphql_todo_target_entity_reuse_preloaded is disabled' do
      before do
        stub_feature_flags(graphql_todo_target_entity_reuse_preloaded: false)

        post_graphql(query, current_user: current_user)
      end

      it 'returns the target of each to-do item' do
        expect(target_entity_ids).to include(expected_target_entity_ids)
      end
    end
  end

  context 'when requesting a single field' do
    let(:fields) do
      <<~QUERY
      nodes {
        id
      }
      QUERY
    end

    it 'avoids N+1 queries', :request_store, quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9323' do
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

      project2 = create(:project)
      project2.add_developer(current_user)
      issue2 = create(:issue, project: project2)
      create(:todo, user: current_user, target: issue2, project: project2)

      # An additional query is made for each different group that owns a todo through a project
      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control).with_threshold(2)
    end
  end

  context 'when requesting the note of unmergeable to-dos' do
    # Mirrors the note fields of app/assets/javascripts/todos/components/queries/todo.fragment.graphql
    let(:fields) do
      <<~QUERY
      nodes {
        id
        note {
          id
          bodyFirstLineHtml
          systemNoteMetadata {
            id
            action
          }
        }
      }
      QUERY
    end

    def create_unmergeable_todo(action)
      merge_request = create(:merge_request, :unique_branches, source_project: project)
      note = create(:note_on_merge_request, :system, noteable: merge_request, project: project,
        note: 'aborted the automatic merge')
      create(:system_note_metadata, note: note, action: action)

      create(:todo, :unmergeable, user: current_user, project: project, target: merge_request, note: note)
    end

    def system_note_actions
      graphql_data.dig('currentUser', 'todos', 'nodes').filter_map do |node|
        node.dig('note', 'systemNoteMetadata', 'action')
      end
    end

    it 'avoids N+1 queries when loading the system note metadata', :request_store, :aggregate_failures do
      create_unmergeable_todo('auto_merge_aborted_target_branch_updated')

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, current_user: current_user)
      end

      expect(system_note_actions).to contain_exactly('auto_merge_aborted_target_branch_updated')

      create_unmergeable_todo('auto_merge_aborted_target_branch_updated')
      create_unmergeable_todo('auto_merge_aborted_target_branch_merged')
      create_unmergeable_todo('auto_merge_aborted_target_branch_merged')
      create_unmergeable_todo('merge')

      # Scoped to SystemNoteMetadata: authorizing each note also loads its noteable, a separate
      # N+1 that predates the systemNoteMetadata field.
      expect { post_graphql(query, current_user: current_user) }
        .not_to exceed_all_query_limit(control).for_model(SystemNoteMetadata)
      expect(system_note_actions).to contain_exactly(
        'auto_merge_aborted_target_branch_updated',
        'auto_merge_aborted_target_branch_updated',
        'auto_merge_aborted_target_branch_merged',
        'auto_merge_aborted_target_branch_merged',
        'merge'
      )
    end
  end

  context 'when requesting the review id of review-submitted to-do items' do
    let_it_be(:reviewer) { create(:user) }

    let(:fields) do
      <<~QUERY
      nodes {
        id
        reviewId
      }
      QUERY
    end

    def create_review_todo(source_branch)
      merge_request = create(:merge_request, source_project: project, source_branch: source_branch, target_branch: 'master')
      todo = create(:todo, :review_submitted, project: project, user: current_user, author: reviewer, target: merge_request)
      create(:todo_review_link, todo: todo, review: create(:review, author: reviewer, merge_request: merge_request, project: project))

      todo
    end

    it 'adds no query per to-do item once the link is recorded', :request_store do
      create_review_todo('feature')
      post_graphql(query, current_user: current_user) # warm caches so the control counts only the page
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

      create_review_todo('fix')
      create_review_todo('markdown')

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end
end
