# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::Samplers::ActionCableSampler do
  let(:action_cable) { instance_double(ActionCable::Server::Base) }
  let(:subscriptions) do
    instance_double(Gitlab::Graphql::Subscriptions::ActionCableWithLoadBalancing, coalescer_size: 7)
  end

  subject { described_class.new(action_cable: action_cable, subscriptions: -> { subscriptions }, logger: double) }

  it_behaves_like 'metrics sampler', 'ACTION_CABLE_SAMPLER'

  describe '#sample' do
    let(:pool) { instance_double(Concurrent::ThreadPoolExecutor) }

    before do
      allow(action_cable).to receive_message_chain(:worker_pool, :executor).and_return(pool)
      allow(action_cable).to receive(:connections).and_return([])
      allow(pool).to receive_messages(
        min_length: 1,
        max_length: 2,
        length: 3,
        largest_length: 4,
        completed_task_count: 5,
        queue_length: 6
      )
    end

    it 'includes active connections' do
      expect(subject.metrics[:active_connections]).to receive(:set).with({}, 0)

      subject.sample
    end

    it 'includes minimum worker pool size' do
      expect(subject.metrics[:pool_min_size]).to receive(:set).with({}, 1)

      subject.sample
    end

    it 'includes maximum worker pool size' do
      expect(subject.metrics[:pool_max_size]).to receive(:set).with({}, 2)

      subject.sample
    end

    it 'includes current worker pool size' do
      expect(subject.metrics[:pool_current_size]).to receive(:set).with({}, 3)

      subject.sample
    end

    it 'includes largest worker pool size' do
      expect(subject.metrics[:pool_largest_size]).to receive(:set).with({}, 4)

      subject.sample
    end

    it 'includes worker pool completed task count' do
      expect(subject.metrics[:pool_completed_tasks]).to receive(:set).with({}, 5)

      subject.sample
    end

    it 'includes worker pool pending task count' do
      expect(subject.metrics[:pool_pending_tasks]).to receive(:set).with({}, 6)

      subject.sample
    end

    it 'includes the GraphQL subscription coalescer key count' do
      expect(subject.metrics[:graphql_coalescer_keys]).to receive(:set).with({}, 7)

      subject.sample
    end

    context 'when the application has not finished initializing' do
      before do
        allow(Rails.application).to receive(:initialized?).and_return(false)
      end

      it 'does not load the GraphQL schema' do
        sampler = described_class.new(action_cable: action_cable, subscriptions: -> { raise 'schema loaded' },
          logger: double)

        expect { sampler.sample }.not_to raise_error
      end

      it 'does not set the GraphQL subscription coalescer key count' do
        expect(subject.metrics[:graphql_coalescer_keys]).not_to receive(:set)

        subject.sample
      end

      it 'still includes the other metrics' do
        expect(subject.metrics[:active_connections]).to receive(:set).with({}, 0)

        subject.sample
      end
    end
  end
end
