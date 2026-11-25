# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item child types read with a granular token', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :private, group: group) }
  let_it_be(:user) { create(:user, reporter_of: group) }

  let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

  describe 'Milestone.stats' do
    let_it_be(:milestone) { create(:milestone, project: project) }

    let(:boundary_object) { project }
    let(:query) { graphql_query_for(:milestone, { id: global_id_of(milestone) }, 'stats { totalIssuesCount }') }

    it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
      :read_milestone do
      let(:skipped_data_path) { %i[milestone stats] }
    end
  end

  describe 'timelogCategories' do
    let_it_be(:group_category) { create(:timelog_category, namespace: group) }
    let_it_be(:project_category) { create(:timelog_category, namespace: project.project_namespace) }

    let(:fields) { 'timelogCategories { nodes { name } }' }

    context 'when querying through the group' do
      let(:boundary_object) { group }
      let(:query) { graphql_query_for(:group, { full_path: group.full_path }, fields) }

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_group, :read_namespace] do
        let(:skipped_data_path) { %i[group timelog_categories nodes] }
      end
    end

    context 'when querying through the namespace' do
      let(:boundary_object) { group }
      let(:query) { graphql_query_for(:namespace, { full_path: group.full_path }, fields) }

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        :read_namespace do
        let(:skipped_data_path) { %i[namespace timelog_categories nodes] }
      end
    end

    context 'when querying through the project' do
      let(:boundary_object) { project }
      let(:query) { graphql_query_for(:project, { full_path: project.full_path }, fields) }

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_namespace] do
        let(:skipped_data_path) { %i[project timelog_categories nodes] }
      end

      it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_project do
        let(:parent_data_path) { %i[project] }
        let(:field_data_path) { %i[project timelog_categories] }
      end
    end
  end

  describe 'work item widgets' do
    let_it_be(:work_item) { create(:work_item, project: project, time_estimate: 3600) }

    let(:boundary_object) { project }
    let(:query) { graphql_query_for(:work_item, { id: global_id_of(work_item) }, "features { #{fields} }") }

    context 'when querying the time tracking attributes' do
      let(:fields) { 'timeTracking { humanReadableAttributes { timeEstimate } }' }

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        :read_work_item do
        let(:skipped_data_path) { %i[work_item features time_tracking human_readable_attributes] }
      end
    end

    context 'when querying the error tracking stack trace' do
      let_it_be(:sentry_issue) { create(:sentry_issue, issue: work_item) }

      let(:fields) { 'errorTracking { stackTrace { nodes { filename context { lineNumber } } } }' }
      let(:latest_event) do
        instance_double(Gitlab::ErrorTracking::ErrorEvent,
          issue_id: sentry_issue.sentry_issue_identifier,
          date_received: 1.day.ago,
          stack_trace_entries: [{ 'filename' => 'test.rb', 'lineNo' => 2, 'context' => [[2, 'yes']] }])
      end

      before do
        allow_next_instance_of(ErrorTracking::IssueLatestEventService) do |instance|
          allow(instance).to receive(:execute).and_return({ status: :success, latest_event: latest_event })
        end
      end

      %i[filename context].each do |field|
        it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
          :read_work_item do
          let(:skipped_data_path) { [:work_item, :features, :error_tracking, :stack_trace, :nodes, field] }
        end
      end
    end
  end
end
