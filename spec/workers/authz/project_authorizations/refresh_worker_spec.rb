# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::ProjectAuthorizations::RefreshWorker, feature_category: :permissions do
  let(:worker) { described_class.new }
  let(:normal) { Gitlab::Database::HealthStatus::Signals::Normal.new(Object, reason: 'test') }
  let(:stop) { Gitlab::Database::HealthStatus::Signals::Stop.new(Object, reason: 'test') }

  before do
    allow(Gitlab::Database::HealthStatus).to receive(:evaluate).and_return([normal])
  end

  # Events don't say whether access is being removed, so deferring would hold revocations too. It scales less instead.
  it 'is never deferred on database health' do
    expect(described_class.defer_on_database_health_signal?).to be(false)
  end

  it 'runs at most one job per slot' do
    expect(described_class.get_concurrency_limit).to eq(described_class::SLOTS)
  end

  it 'never overlaps a slot with itself, and reruns it once a cron run skipped it' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    expect(described_class.get_deduplication_options).to include(if_deduplicated: :reschedule_once)
  end

  describe '.scale_up' do
    it 'queues a slot per worker after the polling one' do
      expect(described_class).to receive(:bulk_perform_async).with([[2], [3], [4]])

      described_class.scale_up(3)
    end

    it 'queues nothing for no workers' do
      expect(described_class).not_to receive(:bulk_perform_async)

      described_class.scale_up(0)
    end

    it 'queues at most every slot while the database health check finds no stop' do
      expect(described_class).to receive(:bulk_perform_async).with((2..described_class::SLOTS).map { |n| [n] })

      expect(described_class.scale_up(100)).to be(false)
    end

    context 'when the database health check says stop' do
      before do
        allow(Gitlab::Database::HealthStatus).to receive(:evaluate).and_return([stop])
      end

      it 'queues only the stressed slots, on the main database with the global indicators' do
        expect(Gitlab::Database::HealthStatus).to receive(:evaluate)
          .with(having_attributes(connection: ApplicationRecord.connection),
            Gitlab::Database::HealthStatus::GLOBAL_INDICATORS)
        expect(described_class).to receive(:bulk_perform_async)
          .with((2..described_class::STRESSED_SLOTS).map { |n| [n] })

        expect(described_class.scale_up(100)).to be(true)
      end

      it 'skips the check when the stressed slots are enough' do
        expect(Gitlab::Database::HealthStatus).not_to receive(:evaluate)
        expect(described_class).to receive(:bulk_perform_async).with([[2], [3], [4]])

        expect(described_class.scale_up(3)).to be(false)
      end
    end

    it 'checks the database health at most once per cache period', :use_clean_rails_memory_store_caching do
      expect(Gitlab::Database::HealthStatus).to receive(:evaluate).once.and_return([stop])
      allow(described_class).to receive(:bulk_perform_async)

      2.times { described_class.scale_up(100) }
    end
  end

  describe '#perform' do
    context 'for the cron run' do
      it 'queues only the polling slot, so an idle queue runs one job' do
        expect(described_class).to receive(:perform_async).with(described_class::POLLING_SLOT)
        expect(described_class).not_to receive(:bulk_perform_async)

        worker.perform
      end
    end

    context 'for a slot' do
      let(:dropped_counts) { { 'user' => 1 } }
      let(:expanded_counts) { { 'namespace_subtree' => 1 } }

      def expect_service(poll_interval:, drained:)
        expect_next_instance_of(Authz::ProjectAuthorizations::RefreshService,
          an_instance_of(Gitlab::Metrics::RuntimeLimiter), poll_interval: poll_interval) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success(
            payload: { drained: drained, dropped_counts: dropped_counts, expanded_counts: expanded_counts }))
        end
      end

      it 'polls in the polling slot until its runtime limit, and logs the counts' do
        expect_service(poll_interval: described_class::POLL_INTERVAL, drained: false)

        expect(worker).to receive(:log_extra_metadata_on_done).with(:drained, false)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:dropped_counts, dropped_counts)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:expanded_counts, expanded_counts)

        worker.perform(described_class::POLLING_SLOT)
      end

      it 'stops at an empty queue in the other slots, and logs the counts' do
        expect_service(poll_interval: nil, drained: true)

        expect(worker).to receive(:log_extra_metadata_on_done).with(:drained, true)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:dropped_counts, dropped_counts)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:expanded_counts, expanded_counts)

        worker.perform(2)
      end

      it 'runs a slot above the stressed ones while the database health check finds no stop' do
        expect_service(poll_interval: nil, drained: true)

        worker.perform(described_class::SLOTS)
      end

      context 'when the database health check says stop' do
        before do
          allow(Gitlab::Database::HealthStatus).to receive(:evaluate).and_return([stop])
        end

        it 'exits a slot above the stressed ones without leasing' do
          expect(Authz::ProjectAuthorizations::RefreshService).not_to receive(:new)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:database_unhealthy, true)

          worker.perform(described_class::STRESSED_SLOTS + 1)
        end

        it 'still runs the stressed slots' do
          expect_service(poll_interval: nil, drained: true)

          worker.perform(described_class::STRESSED_SLOTS)
        end
      end

      it 'gives the service the job runtime limit' do
        expect(Gitlab::Metrics::RuntimeLimiter).to receive(:new).with(described_class::MAX_RUNTIME).and_call_original
        allow_next_instance_of(Authz::ProjectAuthorizations::RefreshService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: {}))
        end

        worker.perform(1)
      end
    end
  end
end
