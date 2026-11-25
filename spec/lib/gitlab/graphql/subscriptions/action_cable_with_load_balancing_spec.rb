# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Subscriptions::ActionCableWithLoadBalancing, feature_category: :shared do
  let(:field) { Types::SubscriptionType.fields.each_value.first }
  let(:event) { ::GraphQL::Subscriptions::Event.new(name: 'test-event', arguments: {}, field: field) }
  let(:object) { build(:project, id: 1) }
  let(:envelope_class) { Gitlab::Graphql::Subscriptions::Envelope }
  let(:action_cable) { instance_double(::ActionCable::Server::Broadcasting) }

  subject(:subscriptions) { described_class.new(schema: GitlabSchema) }

  include_context 'when tracking WAL location reference'

  before do
    allow(::ActionCable).to receive(:server).and_return(action_cable)
    allow(::Labkit::Correlation::CorrelationId).to receive(:current_id).and_return('abc-123')
  end

  context 'when triggering subscription' do
    shared_examples_for 'injecting WAL locations' do
      it 'injects correct WAL location into message' do
        expect(action_cable).to receive(:broadcast) do |topic, payload|
          expect(topic).to match(/^graphql-event/)
          expect(Gitlab::Json.parse(payload)).to match({
            envelope_class::KEY_WAL_LOCATIONS => expected_locations,
            envelope_class::KEY_CORRELATION_ID => 'abc-123',
            envelope_class::KEY_PAYLOAD => { '__gid__' => 'Z2lkOi8vZ2l0bGFiL1Byb2plY3QvMQ' }
          })
        end

        subscriptions.execute_all(event, object)
      end
    end

    context 'when database load balancing is disabled' do
      let!(:expected_locations) { {} }

      before do
        stub_load_balancing_disabled!
      end

      it_behaves_like 'injecting WAL locations'
    end

    context 'when database load balancing is enabled' do
      before do
        stub_load_balancing_enabled!
      end

      context 'when write was not performed' do
        before do
          stub_no_writes_performed!
        end

        context 'when replica hosts are available' do
          let!(:expected_locations) { expect_tracked_locations_when_replicas_available.with_indifferent_access }

          it_behaves_like 'injecting WAL locations'
        end

        context 'when no replica hosts are available' do
          let!(:expected_locations) { expect_tracked_locations_when_no_replicas_available.with_indifferent_access }

          it_behaves_like 'injecting WAL locations'
        end
      end

      context 'when write was performed' do
        let!(:expected_locations) { expect_tracked_locations_from_primary_only.with_indifferent_access }

        before do
          stub_write_performed!
        end

        it_behaves_like 'injecting WAL locations'
      end
    end
  end

  describe '#trigger' do
    let(:project) { build_stubbed(:project) }
    let(:pipeline) { build_stubbed(:ci_pipeline, project: project) }

    subject(:trigger) { subscriptions.trigger(:ci_pipeline_statuses_updated, { project_id: project.to_gid }, pipeline) }

    before do
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(:ci_pipeline_statuses_subscription, scope: { project: project })
        .and_return(throttled)
    end

    context 'when the rate limit of the subscription allows the event' do
      let(:throttled) { false }

      it 'broadcasts the event' do
        expect(subscriptions).to receive(:execute_all)

        trigger
      end
    end

    context 'when the rate limit of the subscription blocks the event' do
      let(:throttled) { true }

      it 'counts the event instead of broadcasting it', :aggregate_failures do
        expect(subscriptions).not_to receive(:execute_all)
        expect(Gitlab::Graphql::Subscriptions::DroppedEvents).to receive(:count)
          .with(:ci_pipeline_statuses_updated, :rate_limited)

        trigger
      end
    end

    context 'when the subscription has no rate limit' do
      let(:throttled) { false }

      it 'broadcasts the event without checking a limit' do
        expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)
        expect(subscriptions).to receive(:execute_all)

        subscriptions.trigger(:ci_pipeline_status_updated, { pipeline_id: pipeline.to_gid }, pipeline)
      end
    end

    context 'when the field does not exist' do
      let(:throttled) { false }

      it 'leaves the error to graphql-ruby' do
        expect { subscriptions.trigger(:not_a_subscription, {}, pipeline) }
          .to raise_error(GraphQL::Subscriptions::InvalidTriggerError)
      end
    end
  end

  context 'when receiving a broadcast' do
    let_it_be(:broadcast_project) { create(:project) }

    let(:serialized_project) { { '__gid__' => Base64.urlsafe_encode64(broadcast_project.to_gid.to_s, padding: false) } }

    let(:raw_message) do
      Gitlab::Json.dump({
        envelope_class::KEY_WAL_LOCATIONS => wal_locations,
        envelope_class::KEY_CORRELATION_ID => 'abc-123',
        envelope_class::KEY_PAYLOAD => serialized_project
      })
    end

    let(:wal_locations) { { 'main' => current_location } }

    def primary_pinned?
      Gitlab::Database::LoadBalancing::SessionMap
        .current(ApplicationRecord.load_balancer)
        .use_primary?
    end

    def load_message!
      subscriptions.send(:load_message, raw_message, nil)
    end

    it 'leaves loading to execute_update, so that receiving a message reads nothing', :aggregate_failures do
      subscriptions

      expect(::GraphQL::Subscriptions::Serialize).not_to receive(:load)
      expect(Gitlab::Database::LoadBalancing::SessionMap).not_to receive(:with_sessions)

      expect(subscriptions.load_action_cable_message(raw_message, nil))
        .to eq(described_class::UnloadedMessage.new(raw_message, nil))
    end

    it 'loads with an envelope that is already parsed without parsing it again', :aggregate_failures do
      envelope = envelope_class.parse(raw_message)
      allow(envelope_class).to receive(:parse).and_call_original

      expect(subscriptions.send(:load_message, raw_message, nil, envelope)).to include(
        envelope_class::KEY_PAYLOAD => broadcast_project
      )
      expect(envelope_class).not_to have_received(:parse)
    end

    # Instantiating the transport reflects on Serialize.load's arity, so it has to exist
    # before the spy below replaces that method.
    def spy_on_payload_resolution!
      subscriptions

      pinned = { during_lookup: nil }

      allow(::GraphQL::Subscriptions::Serialize).to receive(:load).and_wrap_original do |original, *args|
        pinned[:during_lookup] = primary_pinned?
        original.call(*args)
      end

      pinned
    end

    context 'when database replicas are not in sync' do
      before do
        stub_replica_available!(false)
      end

      it 'pins to the primary before the payload is resolved' do
        pinned = spy_on_payload_resolution!

        expect(load_message!).to match(
          envelope_class::KEY_PAYLOAD => broadcast_project,
          envelope_class::KEY_WAL_LOCATIONS => wal_locations,
          envelope_class::KEY_CORRELATION_ID => 'abc-123'
        )
        expect(pinned[:during_lookup]).to be(true)
      end
    end

    context 'when database replicas are in sync' do
      before do
        stub_replica_available!(true)
      end

      it 'does not pin to the primary' do
        pinned = spy_on_payload_resolution!

        expect(load_message!).to match(
          envelope_class::KEY_PAYLOAD => broadcast_project,
          envelope_class::KEY_WAL_LOCATIONS => wal_locations,
          envelope_class::KEY_CORRELATION_ID => 'abc-123'
        )
        expect(pinned[:during_lookup]).to be(false)
      end
    end

    context 'when WAL locations are absent' do
      let(:wal_locations) { {} }

      it 'pins to the primary' do
        pinned = spy_on_payload_resolution!

        load_message!

        expect(pinned[:during_lookup]).to be(true)
      end
    end

    context 'when the envelope cannot be parsed' do
      before do
        stub_replica_available!(true)
      end

      context 'when it exceeds the safe parser limits but is valid JSON' do
        before do
          stub_const('Gitlab::Json::PARSE_LIMITS', Gitlab::Json::PARSE_LIMITS.merge(max_json_size_bytes: 1))
        end

        it 'pins to the primary and still resolves the payload' do
          pinned = spy_on_payload_resolution!

          expect(load_message!).to match(
            envelope_class::KEY_PAYLOAD => broadcast_project,
            envelope_class::KEY_WAL_LOCATIONS => wal_locations,
            envelope_class::KEY_CORRELATION_ID => 'abc-123'
          )
          expect(pinned[:during_lookup]).to be(true)
        end
      end

      context 'when it is malformed' do
        let(:raw_message) { '{"wal_locations":' }

        it 'pins to the primary and leaves the failure to the serializer' do
          expect { load_message! }.to raise_error(::JSON::ParserError)

          expect(primary_pinned?).to be(true)
        end
      end
    end

    context 'when it logs the fallback' do
      def expect_fallback_logged(reason)
        expect(Gitlab::Database::LoadBalancing::Logger).to receive(:info).with(
          event: :graphql_subscription_primary_fallback,
          fallback_reason: reason,
          ::Labkit::Fields::CORRELATION_ID => 'abc-123'
        )
      end

      it 'records the originating correlation id and that the replicas were behind' do
        stub_replica_available!(false)
        expect_fallback_logged(:replicas_behind)

        load_message!
      end

      context 'when WAL locations are absent' do
        let(:wal_locations) { {} }

        it 'says so' do
          expect_fallback_logged(:wal_locations_absent)

          load_message!
        end
      end

      context 'when the envelope cannot be read' do
        let(:raw_message) { '{"wal_locations":' }

        it 'says so and has no correlation id to record' do
          expect(Gitlab::Database::LoadBalancing::Logger).to receive(:info).with(
            event: :graphql_subscription_primary_fallback,
            fallback_reason: :envelope_unreadable,
            ::Labkit::Fields::CORRELATION_ID => nil
          )

          expect { load_message! }.to raise_error(::JSON::ParserError)
        end
      end

      it 'logs nothing when the replicas are in sync' do
        stub_replica_available!(true)

        expect(Gitlab::Database::LoadBalancing::Logger).not_to receive(:info)

        load_message!
      end
    end

    context 'when the message is not a wrapped envelope' do
      let(:raw_message) { Gitlab::Json.dump(serialized_project) }

      it 'makes no routing decision and passes the payload through' do
        expect(Gitlab::Database::LoadBalancing::SessionMap).not_to receive(:with_sessions)

        expect(load_message!).to eq(broadcast_project)
      end
    end
  end

  context 'when handling event' do
    def handle_event!
      subscriptions.execute_update('sub:123', event, {
        envelope_class::KEY_WAL_LOCATIONS => { 'main' => current_location },
        envelope_class::KEY_PAYLOAD => { '__gid__' => 'Z2lkOi8vZ2l0bGFiL1Byb2plY3QvMQ' }
      })
    end

    before do
      allow(action_cable).to receive(:broadcast)
    end

    it 'leaves the routing decision to the load before it' do
      stub_replica_available!(false)

      expect(Gitlab::Database::LoadBalancing::SessionMap).not_to receive(:with_sessions)

      handle_event!
    end

    context 'when event payload is not wrapped' do
      it 'does not attempt to unwrap it' do
        expect(object).not_to receive(:[]).with(envelope_class::KEY_PAYLOAD)

        subscriptions.execute_update('sub:123', event, object)
      end
    end

    it 'strips out WAL location information before broadcasting payload' do
      expect(action_cable).to receive(:broadcast) do |topic, payload|
        expect(topic).to eq('graphql-subscription:sub:123')
        expect(payload).to eq({ more: false })
      end

      handle_event!
    end
  end

  describe 'coalescing the updates of a stream' do
    let(:topic) { ':ciPipelineStatusesUpdated:projectId:gid://gitlab/Project/1' }
    let(:fingerprint) { 'fingerprint-1' }
    let(:leader) { stream_event('sub-1') }
    let(:follower) { stream_event('sub-2') }
    let(:timers) { [] }
    let(:worker_pool) { instance_double(ActionCable::Server::Worker) }
    let(:connection) { instance_double(ActionCable::Connection::Base, worker_pool: worker_pool) }
    let(:channel) { instance_double(ApplicationCable::Channel, connection: connection) }
    let(:stream) { {} }
    let(:result_namespace) { {} }
    let(:result) do
      instance_double(GraphQL::Query::Result,
        context: instance_double(GraphQL::Query::Context, namespace: result_namespace))
    end

    let(:executed_messages) { [] }
    let(:executed) { [] }
    let(:current_user) { build_stubbed(:user) }
    let(:coalesce_policy) { nil }

    def stream_event(subscription_id)
      instance_double(::GraphQL::Subscriptions::Event,
        name: 'ciPipelineStatusesUpdated', topic: topic, fingerprint: fingerprint,
        context: { subscription_id: subscription_id, current_user: current_user, channel: channel })
    end

    def message(gid: 'pipeline-1', wal_locations: { 'main' => '0/10' })
      Gitlab::Json.dump({
        envelope_class::KEY_WAL_LOCATIONS => wal_locations,
        envelope_class::KEY_CORRELATION_ID => 'abc-123',
        envelope_class::KEY_PAYLOAD => { '__gid__' => gid }
      })
    end

    def receive_message(raw)
      stream.fetch(:handler).call(raw)
    end

    def end_window
      timers.shift.call
    end

    before do
      allow(Subscriptions::Ci::Pipelines::StatusesUpdated).to receive(:coalesce_policy).and_return(coalesce_policy)
      allow(Concurrent::ScheduledTask).to receive(:execute) { |_delay, &block| timers << block }
      allow(channel).to receive(:stream_from) { |_name, **_options, &block| stream[:handler] = block }
      allow(worker_pool).to receive(:async_invoke) do |receiver, method, *args, **_connection|
        receiver.send(method, *args)
      end
      allow(subscriptions).to receive(:load_message) do |raw, _context|
        executed_messages << Gitlab::Json.parse(raw)
        :loaded
      end
      allow(subscriptions).to receive(:read_subscription)
        .and_return({ query_string: '', variables: {}, context: {}, operation_name: nil })
      allow(subscriptions.instance_variable_get(:@schema)).to receive(:execute) do |**options|
        executed << [options[:context][:subscription_id], options[:root_value]]
        result
      end
      allow(subscriptions).to receive(:deliver)

      subscriptions.instance_variable_get(:@events)[topic][fingerprint].push(leader, follower)
      subscriptions.send(:setup_stream, channel, leader)
    end

    shared_examples 'running every update at once' do
      it 'runs each update for the fingerprint and delivers it to every subscriber', :aggregate_failures do
        receive_message(message)
        receive_message(message)

        expect(executed).to eq([['sub-1', :loaded]] * 2)
        expect(subscriptions).to have_received(:deliver).with('sub-2', result).twice
        expect(timers).to be_empty
      end
    end

    context 'when the subscription does not declare coalesce' do
      it_behaves_like 'running every update at once'

      it 'never gives an update to the coalescer' do
        receive_message(message)

        expect(subscriptions.coalescer_size).to eq(0)
      end
    end

    context 'with the window that ciPipelineStatusesUpdated declares' do
      # Read before the stub in the outer `before` replaces it.
      let(:coalesce_policy) { Subscriptions::Ci::Pipelines::StatusesUpdated.coalesce_policy }

      it 'runs a burst for a pipeline once, then once more after the default window', :aggregate_failures do
        3.times { receive_message(message) }

        expect(executed.size).to eq(1)
        expect(Concurrent::ScheduledTask).to have_received(:execute).with(0.5.seconds)

        end_window

        expect(executed.size).to eq(2)
      end
    end

    context 'when the subscription declares coalesce' do
      let(:coalesce_policy) { Gitlab::Graphql::Subscriptions::CoalescePolicy.new(2.seconds) }

      it 'runs the first update at once and the newest of a burst when the window ends', :aggregate_failures do
        receive_message(message(wal_locations: { 'main' => '0/10' }))
        receive_message(message(wal_locations: { 'main' => '0/30' }))
        receive_message(message(wal_locations: { 'main' => '0/20' }))

        expect(executed.size).to eq(1)

        end_window

        expect(executed).to eq([['sub-1', :loaded]] * 2)
        expect(subscriptions).to have_received(:deliver).with('sub-2', result).twice
        expect(executed_messages.last[envelope_class::KEY_WAL_LOCATIONS]).to eq('main' => '0/30')
      end

      it 'keeps reading from the primary when an update of the burst has no WAL locations' do
        receive_message(message)
        receive_message(message(wal_locations: {}))
        receive_message(message)

        end_window

        expect(executed_messages.last[envelope_class::KEY_WAL_LOCATIONS]).to eq({})
      end

      it 'merges bursts for each record apart' do
        receive_message(message(gid: 'pipeline-1'))
        receive_message(message(gid: 'pipeline-2'))

        expect(executed.size).to eq(2)
      end

      it 'counts what it does with each update' do
        %i[run deferred flushed].each do |outcome|
          expect(Gitlab::Graphql::Subscriptions::CoalescedEvents).to receive(:count)
            .with('ciPipelineStatusesUpdated', outcome)
        end

        receive_message(message)
        receive_message(message)
        end_window
      end

      it 'does not run a merged update when the fingerprint has no subscribers left' do
        receive_message(message)
        receive_message(message)
        subscriptions.instance_variable_get(:@events)[topic].delete(fingerprint)

        end_window

        expect(executed.size).to eq(1)
      end

      it 'does not run a merged update when the topic has no subscribers left' do
        receive_message(message)
        receive_message(message)
        subscriptions.instance_variable_get(:@events).delete(topic)

        end_window

        expect(executed.size).to eq(1)
      end

      it 'runs a merged update for the subscribers left when the first one is gone', :aggregate_failures do
        receive_message(message)
        receive_message(message)
        subscriptions.instance_variable_get(:@events)[topic][fingerprint].delete(leader)

        end_window

        expect(executed.last).to eq(['sub-2', :loaded])
      end

      it 'opens no window in the stream of a subscriber that graphql-ruby does not run the update for' do
        follower_handler = nil
        allow(channel).to receive(:stream_from) { |_name, **_options, &block| follower_handler = block }
        subscriptions.send(:setup_stream, channel, follower)

        follower_handler.call(message)
        follower_handler.call(message)

        expect(timers).to be_empty
      end

      it 'looks up the policy of a field once' do
        receive_message(message(gid: 'pipeline-1'))
        receive_message(message(gid: 'pipeline-2'))

        expect(Subscriptions::Ci::Pipelines::StatusesUpdated).to have_received(:coalesce_policy).once
      end

      it 'reports the records with an open window' do
        receive_message(message(gid: 'pipeline-1'))
        receive_message(message(gid: 'pipeline-2'))

        expect(subscriptions.coalescer_size).to eq(2)
      end

      it 'delivers nothing when a merged update has no result' do
        receive_message(message)
        receive_message(message)
        result_namespace[:no_update] = true

        end_window

        expect(subscriptions).to have_received(:deliver).twice
      end

      context 'when the payload is not one record' do
        it 'runs every update at once' do
          raw = Gitlab::Json.dump({ envelope_class::KEY_PAYLOAD => { 'work_item_id' => 1, 'action' => 'updated' } })

          receive_message(raw)
          receive_message(raw)

          expect(executed.size).to eq(2)
        end

        it 'runs every update at once for a payload that is not a hash' do
          raw = Gitlab::Json.dump({ envelope_class::KEY_PAYLOAD => 'pipeline-1' })

          receive_message(raw)
          receive_message(raw)

          expect(executed.size).to eq(2)
        end

        it 'runs every update at once for a message without an envelope, such as one from an older process' do
          raw = Gitlab::Json.dump({ '__gid__' => 'pipeline-1' })

          receive_message(raw)
          receive_message(raw)

          expect(executed.size).to eq(2)
        end
      end

      it 'opens no window once the topic has no subscribers left', :aggregate_failures do
        subscriptions.instance_variable_get(:@events).delete(topic)

        receive_message(message)

        expect(timers).to be_empty
        expect(subscriptions.coalescer_size).to eq(0)
      end

      # The scheduler thread is outside ActionCable's worker pool, so its callbacks do not wrap it.
      it 'runs no queries when the window ends, and leaves the update to the worker pool', :aggregate_failures do
        allow(worker_pool).to receive(:async_invoke)

        receive_message(message)
        receive_message(message)

        expect(ActiveRecord::QueryRecorder.new { end_window }.count).to eq(0)
        expect(worker_pool).to have_received(:async_invoke).with(subscriptions, :run_deferred_update, any_args)
      end

      it 'reports an error while deciding and runs the update at once', :aggregate_failures do
        error = RuntimeError.new('boom')
        allow(Gitlab::Graphql::Subscriptions::Coalescer::Key).to receive(:new).and_raise(error)

        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error)

        receive_message(message)

        expect(executed).to eq([['sub-1', :loaded]])
      end

      context 'when graphql_subscription_coalescing is disabled' do
        before do
          stub_feature_flags(graphql_subscription_coalescing: false)
        end

        it_behaves_like 'running every update at once'
      end

      context 'when graphql_subscription_coalescing is enabled for another user' do
        before do
          stub_feature_flags(graphql_subscription_coalescing: build_stubbed(:user))
        end

        it_behaves_like 'running every update at once'

        context 'when the subscriber is signed out' do
          let(:current_user) { nil }

          it_behaves_like 'running every update at once'
        end
      end

      context 'when graphql_subscription_coalescing is enabled for the subscriber' do
        before do
          stub_feature_flags(graphql_subscription_coalescing: current_user)
        end

        it 'merges a burst' do
          receive_message(message)
          receive_message(message)

          expect(executed.size).to eq(1)
        end
      end
    end
  end
end
