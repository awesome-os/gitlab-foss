# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project.valueStreams stage metrics rate limit', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:project) { create(:project, :public, developers: [user, other_user]) }

  let(:stage_id) { Gitlab::GlobalId.as_global_id('test', model_name: Analytics::CycleAnalytics::Stage.to_s).to_s }
  let(:from) { '2024-01-01' }
  let(:to) { '2024-03-01' }
  let(:variables) { { fullPath: project.full_path, stageId: stage_id, from: from, to: to } }

  let(:query) do
    <<~QUERY
      query($fullPath: ID!, $stageId: ID, $from: Date!, $to: Date!) {
        project(fullPath: $fullPath) {
          valueStreams {
            nodes {
              stages(id: $stageId) {
                metrics(timeframe: { start: $from, end: $to }) {
                  count {
                    value
                  }
                }
              }
            }
          }
        }
      }
    QUERY
  end

  def expect_rate_limit_scope(scope, times: 1)
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
    expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
      .with(:value_stream_stage_metrics, hash_including(scope: scope))
      .exactly(times).times
      .and_call_original
  end

  context 'with a signed in user' do
    it_behaves_like 'rate limited endpoint', rate_limit_key: :value_stream_stage_metrics, graphql: true do
      let(:current_user) { user }

      def request
        post_graphql(query, current_user: current_user, variables: variables)
      end

      def request_with_second_scope
        post_graphql(query, current_user: other_user, variables: variables)
      end
    end

    it 'limits by user' do
      expect_rate_limit_scope({ user: user })

      post_graphql(query, current_user: user, variables: variables)

      expect_graphql_errors_to_be_empty
    end

    it 'counts each stage the query asks metrics for' do
      expect_rate_limit_scope({ user: user }, times: 6)

      post_graphql(query, current_user: user, variables: variables.except(:stageId))

      expect_graphql_errors_to_be_empty
      expect(graphql_data_at(:project, :value_streams, :nodes, 0, :stages).size).to eq(6)
    end

    context 'when the timeframe is longer than 180 days' do
      let(:to) { '2024-06-30' }

      it 'rejects the query without counting it' do
        expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)

        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_include('The given date range is larger than 180 days')
      end
    end
  end

  context 'without a signed in user' do
    it_behaves_like 'rate limited endpoint', rate_limit_key: :value_stream_stage_metrics, graphql: true do
      def request
        post_graphql(query, variables: variables, headers: { 'REMOTE_ADDR' => '1.2.3.4' })
      end

      def request_with_second_scope
        post_graphql(query, variables: variables, headers: { 'REMOTE_ADDR' => '1.2.3.5' })
      end
    end

    it 'limits by IP' do
      expect_rate_limit_scope({ ip: '1.2.3.4' })

      post_graphql(query, variables: variables, headers: { 'REMOTE_ADDR' => '1.2.3.4' })

      expect_graphql_errors_to_be_empty
    end
  end
end
