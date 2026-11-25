# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying the plan limits of a project', feature_category: :api do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private, developers: user) }

  let(:query) do
    graphql_query_for(:project, { full_path: project.full_path }, 'projectPlanLimits { ciPipelineSchedules }')
  end

  it 'returns the plan limits' do
    post_graphql(query, current_user: user)

    expect(graphql_errors).to be_nil
    expect(graphql_data_at(:project, :project_plan_limits, :ci_pipeline_schedules))
      .to eq(project.actual_limits.ci_pipeline_schedules)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type', :read_project do
    let(:boundary_object) { project }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    let(:skipped_data_path) { %i[project project_plan_limits] }
  end
end
