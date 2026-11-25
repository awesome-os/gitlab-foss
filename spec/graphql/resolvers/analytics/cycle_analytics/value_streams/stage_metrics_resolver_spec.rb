# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::CycleAnalytics::ValueStreams::StageMetricsResolver,
  feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:stage) { create(:cycle_analytics_stage, project: project) }

  let(:args) { { timeframe: { start: Date.new(2024, 1, 1), end: Date.new(2024, 3, 1) } } }

  def resolve_metrics(current_user:)
    resolve(described_class, obj: stage, args: args, ctx: { current_user: current_user, request: nil })
  end

  describe '#resolve' do
    context 'without a request in the context, as in GraphqlChannel' do
      it 'checks the rate limit by user' do
        expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:value_stream_stage_metrics, scope: { user: user }).and_return(false)

        expect(resolve_metrics(current_user: user)).to be_a(Gitlab::Analytics::CycleAnalytics::DataCollector)
      end

      it 'checks the rate limit by the ActionCable IP address for an anonymous caller' do
        expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:value_stream_stage_metrics, scope: { ip: '1.2.3.4' }).and_return(false)

        result = Gitlab::IpAddressState.with('1.2.3.4') { resolve_metrics(current_user: nil) }

        expect(result).to be_a(Gitlab::Analytics::CycleAnalytics::DataCollector)
      end

      it 'skips the check for an anonymous caller with no IP address' do
        expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)

        expect(resolve_metrics(current_user: nil)).to be_a(Gitlab::Analytics::CycleAnalytics::DataCollector)
      end
    end
  end
end
