# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an issue list for a project', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, :public, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:another_user) { create(:user, reporter_of: group) }
  let_it_be(:milestone1) { create(:milestone, project: project, due_date: 10.days.from_now) }
  let_it_be(:milestone2) { create(:milestone, project: project, due_date: 20.days.from_now) }
  let_it_be(:milestone3) { create(:milestone, project: project, due_date: 30.days.from_now) }
  let_it_be(:milestone4) { create(:milestone, project: project, due_date: 40.days.from_now) }
  let_it_be(:priority1, freeze: false) { create(:label, project: project, priority: 1) }
  let_it_be(:priority2, freeze: false) { create(:label, project: project, priority: 5) }
  let_it_be(:priority3, freeze: false) { create(:label, project: project, priority: 10) }

  let_it_be(:issue_a, freeze: false) do
    create(
      :issue,
      project: project,
      discussion_locked: true,
      labels: [priority3],
      relative_position: 1000,
      milestone: milestone4
    )
  end

  let_it_be(:issue_b, freeze: false) do
    create(
      :issue,
      :with_alert,
      project: project,
      title: 'title matching issue i',
      due_date: 3.days.ago,
      relative_position: 3000,
      labels: [priority2, priority3],
      milestone: milestone1
    )
  end

  let_it_be(:issue_c) do
    create(
      :issue,
      project: project,
      labels: [priority1],
      milestone: milestone2,
      due_date: 1.day.ago,
      relative_position: nil
    )
  end

  let_it_be(:issue_d) do
    create(:issue,
      project: project,
      labels: [priority2],
      due_date: 3.days.from_now,
      relative_position: 5000,
      milestone: milestone3
    )
  end

  let_it_be(:issue_e) do
    create(
      :issue,
      :confidential,
      project: project,
      due_date: 1.day.from_now,
      relative_position: nil
    )
  end

  let_it_be(:subscription) { create(:subscription, subscribable: issue_a, user: current_user, subscribed: true) }
  let_it_be(:unsubscription) do
    create(:subscription, subscribable: issue_b, user: current_user, subscribed: false)
  end

  let_it_be_with_reload(:issues) { [issue_a, issue_b, issue_c, issue_d, issue_e] }

  let(:issue_nodes_path) { %w[project issues nodes] }
  let(:issue_filter_params) { {} }

  # All new specs should be added to the shared example if the change also
  # affects the `issues` query at the root level of the API.
  # Shared example also used in spec/requests/api/graphql/issues_spec.rb
  it_behaves_like 'graphql issue list request spec' do
    let_it_be(:external_user) { create(:user) }

    let(:public_projects) { [project] }

    before_all do
      group.add_developer(current_user)
    end

    # filters
    let(:expected_negated_assignee_issues) { [issue_b, issue_c, issue_d, issue_e] }
    let(:voted_issues) { [issue_a] }
    let(:no_award_issues) { [issue_b, issue_c, issue_d, issue_e] }
    let(:locked_discussion_issues) { [issue_a] }
    let(:unlocked_discussion_issues) { [issue_b, issue_c, issue_d, issue_e] }
    let(:search_title_term) { 'matching issue' }
    let(:title_search_issue) { issue_b }
    let(:confidential_issues) { [issue_e] }
    let(:non_confidential_issues) { [issue_a, issue_b, issue_c, issue_d] }
    let(:public_non_confidential_issues) { non_confidential_issues }
    let(:subscribed_issues) { [issue_a] }
    let(:unsubscribed_issues) { [issue_b] }

    # sorting
    let(:data_path) { [:project, :issues] }
    let(:expected_priority_sorted_asc) { [issue_b, issue_c, issue_d, issue_a, issue_e] }
    let(:expected_priority_sorted_desc) { [issue_a, issue_d, issue_c, issue_b, issue_e] }
    let(:expected_due_date_sorted_desc) { [issue_d, issue_e, issue_c, issue_b, issue_a] }
    let(:expected_due_date_sorted_asc) { [issue_b, issue_c, issue_e, issue_d, issue_a] }
    let(:expected_relative_position_sorted_asc) { [issue_a, issue_b, issue_d, issue_c, issue_e] }
    let(:expected_label_priority_sorted_asc) { [issue_c, issue_d, issue_b, issue_a, issue_e] }
    let(:expected_label_priority_sorted_desc) { [issue_a, issue_d, issue_b, issue_c, issue_e] }
    let(:expected_milestone_sorted_asc) { [issue_b, issue_c, issue_d, issue_a, issue_e] }
    let(:expected_milestone_sorted_desc) { [issue_a, issue_d, issue_c, issue_b, issue_e] }

    # N+1 queries
    let(:same_project_issue1) { issue_a }
    let(:same_project_issue2) { issue_b }

    before_all do
      create(:award_emoji, :upvote, user: current_user, awardable: issue_a)
    end

    def pagination_query(params)
      graphql_query_for(
        :project,
        { full_path: project.full_path },
        query_graphql_field(:issues, params, "#{page_info} nodes { id }")
      )
    end

    def post_query(request_user = current_user)
      post_graphql(query, current_user: request_user)
    end
  end

  describe 'participants' do
    let(:issues) { [issue_a, issue_b] }
    let(:query) do
      graphql_query_for(
        :project,
        { full_path: project.full_path },
        query_graphql_field(
          :issues,
          { iids: issues.map { |issue| issue.iid.to_s } },
          'nodes { id participants { nodes { id } } }'
        )
      )
    end

    def add_note_with_award_emoji(issue)
      note = create(:note_on_issue, noteable: issue, project: project, author: create(:user))
      create(:award_emoji, awardable: note)
    end

    it 'avoids N+1 database queries for the notes', :request_store, :use_sql_query_cache do
      issues.each { |issue| add_note_with_award_emoji(issue) }
      post_graphql(query, current_user: current_user) # warm-up

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { post_graphql(query, current_user: current_user) }
      issues.each { |issue| 2.times { add_note_with_award_emoji(issue) } }

      expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
    end
  end

  describe 'rate limit on participants', :clean_gitlab_redis_rate_limiting, :freeze_time do
    let(:log_state) do
      'applimiter_graphql_participant_fields:limit_graphql_participant_field_requests_by_user_or_ip_log'
    end

    def issues_query(fields = 'participants { nodes { id } }', first: 2)
      graphql_query_for(
        :project,
        { full_path: project.full_path },
        query_graphql_field(:issues, { first: first }, "nodes { id #{fields} }")
      )
    end

    def post_participants_query(request_user = current_user)
      post_graphql(issues_query, current_user: request_user)
    end

    # @note RequestStore::Middleware clears the store when the request ends, so read the state while it runs.
    def track_rate_limit_states
      states = []
      allow(Gitlab::Instrumentation::RateLimitState).to receive(:track).and_wrap_original do |original, results|
        original.call(results)
        next unless results.key?('applimiter_graphql_participant_fields')

        states << Gitlab::Instrumentation::RateLimitState.payload[:rate_limit_state].last
      end

      states
    end

    before do
      stub_const('Gitlab::Graphql::Limit::ParticipantFieldsRateLimit::THRESHOLD', 1)
      stub_application_setting(graphql_participant_fields_request_limit: 1)
    end

    it 'resolves participants past the threshold while the caller is under the limit', :aggregate_failures do
      post_participants_query

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:project, :issues, :nodes)).to all(include('participants' => be_present))
    end

    it 'rejects the request once the caller is over the limit', :aggregate_failures do
      2.times { post_participants_query }

      expect(response).to have_gitlab_http_status(:too_many_requests)
      expect(json_response['errors'].first['message']).to eq(Gitlab::ApplicationRateLimiter.throttled_error_message)
    end

    it 'loads notes only for the issues resolved before the request is rejected', :request_store,
      :use_sql_query_cache do
      post_participants_query

      recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { post_participants_query }

      expect(response).to have_gitlab_http_status(:too_many_requests)
      expect(recorder.log.grep(/\ASELECT "notes"\.\*/).size).to eq(1)
    end

    it 'counts an anonymous caller by IP address' do
      2.times { post_participants_query(nil) }

      expect(response).to have_gitlab_http_status(:too_many_requests)
    end

    it 'counts participants and subscribed together' do
      query = issues_query('subscribed participants { nodes { id } }', first: 1)

      2.times { post_graphql(query, current_user: current_user) }

      expect(response).to have_gitlab_http_status(:too_many_requests)
    end

    it 'counts the queries of a multiplexed request together' do
      queries = Array.new(2) { { query: issues_query(first: 1) } }

      2.times { post_multiplex(queries, current_user: current_user) }

      expect(response).to have_gitlab_http_status(:too_many_requests)
    end

    it 'counts a multiplexed request where only one query selects the fields' do
      queries = [{ query: issues_query }, { query: issues_query('title') }]

      2.times { post_multiplex(queries, current_user: current_user) }

      expect(response).to have_gitlab_http_status(:too_many_requests)
    end

    it 'does not count requests that stay within the threshold' do
      3.times { post_graphql(issues_query(first: 1), current_user: current_user) }

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when the graphql_participant_fields_rate_limit flag is disabled' do
      before do
        stub_feature_flags(graphql_participant_fields_rate_limit: false)
      end

      it 'logs the requests over the limit without blocking them', :aggregate_failures do
        states = track_rate_limit_states

        2.times do
          post_participants_query

          expect(response).to have_gitlab_http_status(:ok)
        end

        expect(states).to eq(["#{log_state}:allow", "#{log_state}:log"])
      end
    end
  end

  def query(params = issue_filter_params)
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('issues', params, fields)
    )
  end
end
