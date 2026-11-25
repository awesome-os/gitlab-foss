# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UsageTrendsMeasurements', feature_category: :devops_reports do
  include GraphqlHelpers

  let(:current_user) { create(:user, :admin) }
  let!(:usage_trends_measurement_1) { create(:usage_trends_measurement, :project_count, recorded_at: 20.days.ago, count: 5) }
  let!(:usage_trends_measurement_2) { create(:usage_trends_measurement, :project_count, recorded_at: 10.days.ago, count: 10) }

  let(:arguments) { 'identifier: PROJECTS' }
  let(:query) { graphql_query_for(:UsageTrendsMeasurements, arguments, 'nodes { count identifier }') }

  before do
    post_graphql(query, current_user: current_user)
  end

  it 'returns measurement objects' do
    expect(graphql_data.dig('usageTrendsMeasurements', 'nodes')).to eq(
      [
        { "count" => 10, 'identifier' => 'PROJECTS' },
        { "count" => 5, 'identifier' => 'PROJECTS' }
      ])
  end

  context 'with recorded_at filters' do
    let(:arguments) do
      %(identifier: PROJECTS,
        recordedAfter: "#{15.days.ago.to_date}",
        recordedBefore: "#{5.days.ago.to_date}")
    end

    it 'returns filtered measurement objects' do
      expect(graphql_data.dig('usageTrendsMeasurements', 'nodes')).to eq(
        [
          { "count" => 10, 'identifier' => 'PROJECTS' }
        ])
    end
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :read_usage_trends_measurement do
    let(:user) { current_user }
    let(:boundary_object) { :instance }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end

  context 'when a granular personal access token can read usage trends measurements' do
    let(:pat) do
      create(:granular_pat, user: current_user, boundary: ::Authz::Boundary.for(:instance),
        permissions: [
          ::Authz::PermissionGroups::Assignable.preferred_for_permission(:read_usage_trends_measurement).name
        ])
    end

    it 'returns the measurements', :aggregate_failures do
      post_graphql(query, token: { personal_access_token: pat })

      expect_graphql_errors_to_be_empty
      expect(graphql_data.dig('usageTrendsMeasurements', 'nodes')).to eq(
        [
          { "count" => 10, 'identifier' => 'PROJECTS' },
          { "count" => 5, 'identifier' => 'PROJECTS' }
        ])
    end
  end
end
