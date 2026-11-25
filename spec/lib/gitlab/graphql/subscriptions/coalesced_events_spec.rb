# frozen_string_literal: true

require 'fast_spec_helper'
require 'prometheus/client'

RSpec.describe Gitlab::Graphql::Subscriptions::CoalescedEvents, feature_category: :api do
  describe '.count' do
    let(:counter) { instance_double(Prometheus::Client::Counter, increment: nil) }

    before do
      described_class.instance_variable_set(:@counter, nil)
      allow(Gitlab::Metrics).to receive(:counter).and_return(counter)
    end

    after do
      described_class.instance_variable_set(:@counter, nil)
    end

    it 'counts the outcome under the snake_case subscription name', :aggregate_failures do
      described_class.count('ciPipelineStatusesUpdated', :overflow)

      expect(Gitlab::Metrics).to have_received(:counter)
        .with(:gitlab_graphql_subscription_coalesced_events_total, an_instance_of(String))
      expect(counter).to have_received(:increment)
        .with({ subscription: 'ci_pipeline_statuses_updated', outcome: 'overflow' })
    end
  end
end
