# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'DetailedStatus and StatusAction with a granular token', feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :private, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
  let_it_be(:job) do
    create(:ci_build, :manual, pipeline: pipeline, project: project, name: 'deploy')
  end

  let(:boundary_object) { project }
  let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  let(:pipeline_query) do
    graphql_query_for(:project, { full_path: project.full_path },
      query_graphql_field(:pipeline, { iid: pipeline.iid.to_s }, fields))
  end

  let(:job_query) do
    graphql_query_for(:project, { full_path: project.full_path },
      query_graphql_field(:job, { id: job.to_global_id.to_s }, fields))
  end

  describe 'Pipeline.detailedStatus' do
    let(:query) { pipeline_query }
    let(:fields) { 'detailedStatus { label }' }

    it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
      [:read_project, :read_pipeline] do
      let(:skipped_data_path) { %i[project pipeline detailed_status label] }
    end
  end

  describe 'CiStage.detailedStatus' do
    let(:query) { pipeline_query }
    let(:fields) { 'stages { nodes { detailedStatus { label } } }' }

    it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
      [:read_project, :read_pipeline] do
      let(:skipped_data_path) { %i[project pipeline stages nodes detailed_status label] }
    end
  end

  describe 'CiJob.detailedStatus' do
    let(:query) { job_query }
    let(:fields) { 'name detailedStatus { label }' }

    it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
      [:read_project, :read_job, :read_pipeline] do
      let(:skipped_data_path) { %i[project job detailed_status label] }
    end

    # The status is read_pipeline data on every path, so a job needs it besides read_job.
    it_behaves_like 'denying a granular token that only authorizes the parent of a field',
      [:read_project, :read_job] do
      let(:parent_data_path) { %i[project job name] }
      let(:field_data_path) { %i[project job detailed_status] }
    end
  end

  describe 'DetailedStatus.action' do
    let(:query) { job_query }
    let(:fields) { 'detailedStatus { action { title } }' }

    it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
      [:read_project, :read_job, :read_pipeline] do
      let(:skipped_data_path) { %i[project job detailed_status action title] }
    end
  end
end
