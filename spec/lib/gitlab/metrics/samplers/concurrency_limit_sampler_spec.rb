# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::Samplers::ConcurrencyLimitSampler, :clean_gitlab_redis_shared_state,
  feature_category: :scalability do
  include ExclusiveLeaseHelpers
  let(:worker_class) { ::Import::ReassignPlaceholderUserRecordsWorker }
  let(:lease_key) { 'gitlab/metrics/samplers/concurrency_limit_sampler:shard:main:queues:default' }
  let(:sampler) { described_class.new }

  subject(:sample) { sampler.sample }

  before do
    allow(Kernel).to receive(:sleep)
    stub_env('SIDEKIQ_SHARD_NAME', 'main')
  end

  it_behaves_like 'metrics sampler', 'CONCURRENCY_LIMIT_SAMPLER'

  describe '#sample' do
    before do
      allow(sampler).to receive(:running).and_return(true)
    end

    it 'publishes while another Redis shard holds a lease for the same queues' do
      stub_env('SIDEKIQ_SHARD_NAME', 'queues_shard_other')
      other_lease = described_class.new.exclusive_lease
      Gitlab::ExclusiveLease.skipping_transaction_check { other_lease.try_obtain }
      stub_env('SIDEKIQ_SHARD_NAME', 'main')
      allow(sampler.exclusive_lease).to receive(:same_uuid?).and_return(true, false)
      expect(sampler).to receive(:report_metrics).once
      expect(sampler).to receive(:reset_metrics).once

      Gitlab::ExclusiveLease.skipping_transaction_check { sample }
    ensure
      other_lease&.cancel
    end

    context 'when lease can be obtained' do
      before do
        allow(sampler.exclusive_lease).to receive(:same_uuid?).and_return(true, false) # run sample once
      end

      context 'for current queue workers when concurrency_limit_sampler_batched_reads is disabled' do
        before do
          stub_feature_flags(concurrency_limit_sampler_batched_reads: false)
          allow(Gitlab::SidekiqConfig).to receive(:workers_without_default).and_return(
            [Gitlab::SidekiqConfig::Worker.new(worker_class, ee: false)]
          )
        end

        it 'fetches data for each worker and sets gauge' do
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit)
            .to receive(:publish).with(worker_class, worker_class.get_concurrency_limit).once
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
            .to receive(:queue_size).once.and_return(1)
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
            .to receive(:concurrent_worker_count).once.and_return(1)
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
            .to receive(:current_limit).once.and_return(1)
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
            .to receive(:override_status).once.and_return({ limit: 7, ttl: 60 })

          queue_size_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_queue_jobs, anything)
                                       .and_return(queue_size_gauge_double)
          expect(queue_size_gauge_double).to receive(:set)
                                               .with({ worker: worker_class.name, feature_category: anything }, 1)
                                               .once
          expect(queue_size_gauge_double).to receive(:set)
                                               .with({ worker: worker_class.name, feature_category: anything }, 0)
                                               .once

          concurrency_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_current_concurrent_jobs, anything)
                                       .and_return(concurrency_gauge_double)
          expect(concurrency_gauge_double).to receive(:set)
                                                .with({ worker: anything, feature_category: anything }, 1)
                                                .once
          expect(concurrency_gauge_double).to receive(:set)
                                                .with({ worker: worker_class.name, feature_category: anything }, 0)
                                                .once

          limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_max_concurrent_jobs, anything)
                                       .and_return(limit_gauge_double)
          expect(limit_gauge_double).to receive(:set)
                                          .with({ worker: worker_class.name, feature_category: anything },
                                            worker_class.get_concurrency_limit)
                                          .once
          expect(limit_gauge_double).to receive(:set)
                                          .with({ worker: worker_class.name, feature_category: anything }, 0)
                                          .once

          current_limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_current_limit, anything)
                                       .and_return(current_limit_gauge_double)
          expect(current_limit_gauge_double).to receive(:set)
                                                  .with({ worker: worker_class.name, feature_category: anything }, 1)
                                                  .once
          expect(current_limit_gauge_double).to receive(:set)
                                                  .with({ worker: worker_class.name, feature_category: anything }, 0)
                                                  .once

          override_limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_override_limit, anything)
                                       .and_return(override_limit_gauge_double)
          expect(override_limit_gauge_double).to receive(:set)
                                                   .with({ worker: worker_class.name, feature_category: anything }, 7)
                                                   .once
          expect(override_limit_gauge_double).to receive(:set)
                                                   .with({ worker: worker_class.name, feature_category: anything }, 0)
                                                   .once

          sample
        end

        it 'reports zero when no override is active' do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
            .to receive_messages(queue_size: 0, concurrent_worker_count: 0, current_limit: 0,
              override_status: { limit: nil, ttl: nil })
          allow(Gitlab::Metrics).to receive(:gauge).and_call_original

          override_limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .with(:sidekiq_concurrency_limit_override_limit, anything)
                                       .and_return(override_limit_gauge_double)
          expect(override_limit_gauge_double).to receive(:set)
                                                   .with({ worker: worker_class.name, feature_category: anything }, 0)
                                                   .twice

          sample
        end
      end

      context 'for current queue workers', :clean_gitlab_redis_concurrency_limit,
        :clean_gitlab_redis_queues_metadata do
        let(:other_worker_class) { ::ProcessCommitWorker }
        let(:service) { Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService }
        let(:reported) { Hash.new { |hash, gauge| hash[gauge] = {} } }

        before do
          allow(Gitlab::SidekiqConfig).to receive(:workers_without_default).and_return(
            [worker_class, other_worker_class].map { |worker| Gitlab::SidekiqConfig::Worker.new(worker, ee: false) }
          )
          %i[queue_size concurrent_workers max_limit current_limit override_limit].each do |gauge|
            allow(sampler).to receive(:"report_#{gauge}") { |worker, value| reported[gauge][worker.name] = value }
          end
        end

        def report_metrics
          reported.clear
          sampler.send(:report_metrics)
          reported.to_h { |gauge, values| [gauge, values.dup] }
        end

        def defer(worker, scope_key = nil)
          job = { 'class' => worker.name, 'args' => [], 'jid' => SecureRandom.hex(12) }
          job[Gitlab::SidekiqMiddleware::ConcurrencyLimit::Scope::JOB_KEY] = scope_key if scope_key
          service.add_to_queue!(job, {})
        end

        it 'reports the same gauges as per-worker reads', :aggregate_failures do
          defer(worker_class)
          defer(worker_class, 'user:1')
          3.times { defer(other_worker_class) }
          stub_feature_flags("disable_sidekiq_concurrency_limit_middleware_#{worker_class.name}": false)
          service.set_override_limit!(worker_class.name, limit: 2)
          service.set_current_limit!(other_worker_class.name, limit: 3)
          allow(Gitlab::SidekiqProcess).to receive_messages(pid: 'pid', tid: 'tid')
          service.track_execution_start(worker_class.name)

          batched = report_metrics
          stub_feature_flags(concurrency_limit_sampler_batched_reads: false)

          expect(batched).to eq(report_metrics)
          expect(batched).to include(
            queue_size: { worker_class.name => 2, other_worker_class.name => 3 },
            concurrent_workers: { worker_class.name => 1, other_worker_class.name => 0 },
            current_limit: { worker_class.name => 2, other_worker_class.name => 3 },
            override_limit: { worker_class.name => 2, other_worker_class.name => 0 }
          )
        end

        it 'scans scope queues only for workers with queued scopes' do
          defer(worker_class)
          defer(other_worker_class, 'user:1')
          scanned = []
          allow(service).to receive(:new).and_wrap_original do |method, worker_name|
            method.call(worker_name).tap do |instance|
              allow(instance).to receive(:queue_size).and_wrap_original do |queue_size|
                scanned << worker_name
                queue_size.call
              end
            end
          end

          report_metrics

          expect(scanned).to eq([other_worker_class.name])
        end

        context 'with a worker that publishes its enqueue default' do
          let(:other_worker_class) { ::AuthorizedProjectsWorker }

          before do
            allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(true)
            stub_env('GITLAB_SIDEKIQ_MAX_REPLICAS', '10')
            stub_env('SIDEKIQ_CONCURRENCY', '20')
          end

          it 'publishes it' do
            stub_const('Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit::CACHE', Concurrent::Map.new)

            report_metrics

            expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit.read(other_worker_class))
              .to eq(other_worker_class.get_concurrency_limit)
          end
        end

        it 'reports the gauges when Redis rejects an enqueue default', :aggregate_failures do
          Gitlab::Redis::QueuesMetadata.with { |redis| redis.set('rejected_write', 'string') }
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit).to receive(:publish) do |*, pipeline:|
            pipeline.lpush('rejected_write', 'value')
          end
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(a_kind_of(Redis::BaseError).and(having_attributes(message: /WRONGTYPE/)),
              first_worker_class: worker_class.name, batch_size: 2)

          expect(report_metrics[:queue_size]).to eq(worker_class.name => 0, other_worker_class.name => 0)
        end

        it 'reports later batches when a batch fails', :aggregate_failures do
          stub_const("#{described_class}::READ_BATCH_SIZE", 1)
          error = Redis::CannotConnectError.new('unavailable')
          calls = 0
          allow(Gitlab::Redis::ConcurrencyLimit).to receive(:with).and_wrap_original do |method, &block|
            calls += 1
            raise error if calls == 1

            method.call(&block)
          end
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(error, first_worker_class: worker_class.name, batch_size: 1)

          expect(report_metrics[:queue_size]).to eq(other_worker_class.name => 0)
        end

        it 'skips only the queue size of a worker whose scope scan fails', :aggregate_failures do
          defer(worker_class, 'user:1')
          defer(other_worker_class)
          scope_queue = "sidekiq:concurrency_limit:throttled_jobs:{#{worker_class.name.underscore}}:scope:user:1"
          Gitlab::Redis::ConcurrencyLimit.with do |redis|
            redis.del(scope_queue)
            redis.hset(scope_queue, 'not', 'a list')
          end
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(a_kind_of(Redis::BaseError).and(having_attributes(message: /WRONGTYPE/)),
              worker_class: worker_class.name)

          gauges = report_metrics

          expect(gauges[:queue_size]).to eq(other_worker_class.name => 1)
          expect(gauges.except(:queue_size).values).to all(include(worker_class.name, other_worker_class.name))
        end
      end

      context 'for workers outside of current queue' do
        let(:test_worker) do
          Class.new do
            def self.name
              'TestWorker'
            end

            include ApplicationWorker

            def perform(*_args); end
          end
        end

        before do
          # Stub the list of currently defined workers
          allow(Gitlab::SidekiqConfig).to receive(:workers_without_default).and_return(
            [
              Gitlab::SidekiqConfig::Worker.new(test_worker, ee: false),
              Gitlab::SidekiqConfig::Worker.new(worker_class, ee: false)
            ]
          )

          # Stub the routing so that test_worker is routed to another queue (test_queue)
          # and the current_queue only consists of worker_class
          allow(::Gitlab::SidekiqConfig::WorkerRouter.global).to receive(:route)
                                                                   .with(test_worker)
                                                                   .and_return('test_queue')
          allow(::Gitlab::SidekiqConfig::WorkerRouter.global).to receive(:route)
                                                                   .with(worker_class)
                                                                   .and_return('current_queue')

          # Stub the sidekiq queues to return current_queue
          allow(Sidekiq.default_configuration).to receive(:queues).and_return(['current_queue'])
        end

        it 'does not report metrics for test_worker' do
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit).not_to receive(:publish).with(test_worker,
            anything)
          queue_size_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_queue_jobs, anything)
                                       .and_return(queue_size_gauge_double)
          expect(queue_size_gauge_double).not_to receive(:set)
                                               .with({ worker: test_worker.name, feature_category: anything }, anything)

          concurrency_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_current_concurrent_jobs, anything)
                                       .and_return(concurrency_gauge_double)
          expect(concurrency_gauge_double).not_to receive(:set)
                                                .with({ worker: test_worker.name, feature_category: anything },
                                                  anything)

          limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_max_concurrent_jobs, anything)
                                       .and_return(limit_gauge_double)
          expect(limit_gauge_double).not_to receive(:set)
                                          .with({ worker: test_worker.name, feature_category: anything }, anything)

          current_limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_current_limit, anything)
                                       .and_return(current_limit_gauge_double)
          expect(current_limit_gauge_double).not_to receive(:set)
                                                  .with({ worker: test_worker.name, feature_category: anything },
                                                    anything)

          override_limit_gauge_double = instance_double(Prometheus::Client::Gauge)
          expect(Gitlab::Metrics).to receive(:gauge)
                                       .once
                                       .with(:sidekiq_concurrency_limit_override_limit, anything)
                                       .and_return(override_limit_gauge_double)
          expect(override_limit_gauge_double).not_to receive(:set)
                                                   .with({ worker: test_worker.name, feature_category: anything },
                                                     anything)

          sample
        end
      end

      it 'observes how long each pass takes' do
        allow(::Gitlab::Metrics::System).to receive(:monotonic_time).and_return(10.0)
        allow(sampler).to receive(:report_metrics) do
          allow(::Gitlab::Metrics::System).to receive(:monotonic_time).and_return(12.5)
        end
        histogram = instance_double(Prometheus::Client::Histogram)
        allow(Gitlab::Metrics).to receive(:histogram)
          .with(:sidekiq_concurrency_limit_sampler_duration_seconds, anything, {}, described_class::DURATION_BUCKETS)
          .and_return(histogram)

        expect(histogram).to receive(:observe).with({}, 2.5).once

        sample
      end

      context 'when lease exists for more than 1 cycle' do
        before do
          allow(sampler.exclusive_lease).to receive(:same_uuid?).and_return(true, true, true, false)
        end

        it 'report metrics while lease exists and afterwards reset the metrics' do
          expect(sampler).to receive(:report_metrics).exactly(3).times
          expect(Kernel).to receive(:sleep).exactly(3).times
          expect(sampler).to receive(:reset_metrics).once

          sample
        end
      end

      context 'when sampler thread stops running' do
        before do
          allow(sampler).to receive(:running).and_return(true, true, false)
          allow(sampler.exclusive_lease).to receive(:same_uuid?).and_return(true)
        end

        it 'reports metrics once and resets the metrics' do
          expect(sampler).to receive(:report_metrics).once
          expect(Kernel).to receive(:sleep).once
          expect(sampler).to receive(:reset_metrics).once

          sample
        end
      end
    end

    context 'when lease cannot be obtained' do
      before do
        stub_exclusive_lease_taken(lease_key)
      end

      it 'does not report anything' do
        expect(sampler).not_to receive(:report_metrics)
        expect(Kernel).not_to receive(:sleep)
        expect(sampler).not_to receive(:reset_metrics)

        sample
      end
    end
  end
end
