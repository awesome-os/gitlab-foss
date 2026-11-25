# frozen_string_literal: true

module Gitlab
  module Metrics
    module Samplers
      class ConcurrencyLimitSampler < BaseSampler
        include ExclusiveLeaseGuard

        # Scrape timing explanation:
        # - Prometheus scrapes occur every 1 minute
        # - Our sampler lease lasts for 5 minutes
        # - After writing metrics, we sleep for 30s until lease expires before resetting the metrics to 0.
        DEFAULT_SAMPLING_INTERVAL_SECONDS = 30
        LEASE_TIMEOUT = 300
        DURATION_BUCKETS = [0.1, 0.5, 1, 5, 15, 30, 60, 120, 300].freeze
        READ_BATCH_SIZE = 100

        # One process per Redis shard and queue list reports while holding the lease.
        # The previous holder resets its metrics so scrapes use the new holder's values.
        def sample
          try_obtain_lease do
            # Keep reporting the metrics while the lease is valid
            # to ensure we have continuous data. Also check if the
            # sampler is still running because a SIGTERM will cause
            # the sleep to be interrupted and the loop to run again
            # until the condition is false.
            while running && exclusive_lease.same_uuid?
              start = ::Gitlab::Metrics::System.monotonic_time
              report_metrics
              duration_metric.observe({}, ::Gitlab::Metrics::System.monotonic_time - start)

              # Ensure that we don't sleep if the state changed
              # after reporting metrics.
              break unless running

              Kernel.sleep(DEFAULT_SAMPLING_INTERVAL_SECONDS)
            end

            # Reset metrics to ensure only the next sample reports fresh data.
            reset_metrics
          end
        end

        private

        # Used by ExclusiveLeaseGuard
        def lease_timeout
          LEASE_TIMEOUT
        end

        def lease_key
          # rubocop:disable Cop/RedisQueueUsage -- Reading the shard-name constant does not access queue Redis.
          shard = ENV.fetch('SIDEKIQ_SHARD_NAME', Gitlab::Redis::Queues::SIDEKIQ_MAIN_SHARD_INSTANCE_NAME)
          # rubocop:enable Cop/RedisQueueUsage
          "#{self.class.name.underscore}:shard:#{shard}:queues:#{current_queues.join(',')}"
        end

        def lease_taken_log_level
          :info
        end

        def report_metrics
          # Read once, so a pass never mixes the two paths.
          return report_metrics_per_worker unless Feature.enabled?(:concurrency_limit_sampler_batched_reads,
            Feature.current_request)

          workers.each_slice(READ_BATCH_SIZE) { |batch| report_batch(batch) }
        end

        def report_metrics_per_worker
          workers.each do |w|
            queue_size = concurrent_limit_service.queue_size(w.name)
            report_queue_size(w, queue_size)

            concurrent_worker_count = concurrent_limit_service.concurrent_worker_count(w.name)
            report_concurrent_workers(w, concurrent_worker_count)

            max_limit = w.get_concurrency_limit
            report_max_limit(w, max_limit)
            Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit.publish(w, max_limit)

            current_limit = concurrent_limit_service.current_limit(w.name)
            report_current_limit(w, current_limit)

            override_limit = concurrent_limit_service.override_status(w.name)[:limit]
            report_override_limit(w, override_limit || 0)
          end
        end

        def report_batch(batch)
          services = batch.map { |w| service_for(w) }
          max_limits = batch.map(&:get_concurrency_limit)

          report_batch_gauges(batch, services, max_limits)
          publish_enqueue_limits(batch, max_limits)
        end

        # One pipeline per Redis store. A pipeline error skips the batch, whose gauges keep their
        # previous values.
        def report_batch_gauges(batch, services, max_limits)
          main_sizes = scope_counts = concurrent_counts = limits = nil

          cross_slot_pipelined(Gitlab::Redis::ConcurrencyLimit) do |pipeline|
            main_sizes = services.map { |service| service.pipeline_main_queue_size(pipeline) }
            scope_counts = services.map { |service| service.pipeline_scope_count(pipeline) }
          end

          cross_slot_pipelined(Gitlab::Redis::QueuesMetadata) do |pipeline|
            concurrent_counts = services.map { |service| service.pipeline_concurrent_worker_count(pipeline) }
            limits = services.map { |service| service.pipeline_limits(pipeline) }
          end

          batch.each_with_index do |w, i|
            queue_size = batch_queue_size(w, services[i], main_sizes[i].value, scope_counts[i].value)

            report_queue_size(w, queue_size) if queue_size
            report_concurrent_workers(w, concurrent_counts[i].value)
            report_max_limit(w, max_limits[i])
            report_current_limit(w, services[i].current_limit_from(limits[i].value))
            report_override_limit(w, limits[i].value.first.to_i)
          end
        rescue ::Redis::BaseError => e
          track_batch_error(e, batch)
        end

        # The scope scan is the heaviest read left in a pass. If it fails, only this worker's queue
        # size keeps its previous value.
        def batch_queue_size(worker, service, main_size, scope_count)
          return main_size if scope_count == 0

          service.queue_size
        rescue ::Redis::BaseError => e
          Gitlab::ErrorTracking.track_exception(e, worker_class: worker.name)
          nil
        end

        # Separate from the reads, so a rejected write doesn't cost the batch its gauges.
        def publish_enqueue_limits(batch, max_limits)
          cross_slot_pipelined(Gitlab::Redis::QueuesMetadata) do |pipeline|
            batch.each_with_index do |w, i|
              Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit.publish(w, max_limits[i], pipeline: pipeline)
            end
          end
        rescue ::Redis::BaseError => e
          track_batch_error(e, batch)
        end

        def track_batch_error(error, batch)
          Gitlab::ErrorTracking.track_exception(error, first_worker_class: batch.first.name, batch_size: batch.size)
        end

        # Reused across passes, like the worker list. The sampler never resumes jobs, so the services'
        # lease state stays unused.
        def service_for(worker)
          (@services ||= {})[worker] ||= concurrent_limit_service.new(worker.name)
        end

        def cross_slot_pipelined(store)
          store.with do |redis|
            Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
              redis.pipelined { |pipeline| yield pipeline }
            end
          end
        end

        def reset_metrics
          workers.each do |w|
            report_queue_size(w, 0)
            report_concurrent_workers(w, 0)
            report_max_limit(w, 0)
            report_current_limit(w, 0)
            report_override_limit(w, 0)
          end
        end

        def workers
          @workers ||= Gitlab::SidekiqConfig
                         .workers_without_default
                         .select do |worker|
                           queue = ::Gitlab::SidekiqConfig::WorkerRouter.global.route(worker.klass)
                           current_queues.include?(queue)
                         end
                         .map(&:klass)
        end

        def current_queues
          Sidekiq.default_configuration.queues
        end

        def concurrent_limit_service
          Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService
        end

        def duration_metric
          @duration_metric ||= Gitlab::Metrics.histogram(:sidekiq_concurrency_limit_sampler_duration_seconds,
            'Time to report the concurrency limit metrics of every worker on the shard.', {}, DURATION_BUCKETS)
        end

        def report_queue_size(worker, queue_size)
          @queue_size_metric ||= Gitlab::Metrics.gauge(:sidekiq_concurrency_limit_queue_jobs,
            'Number of jobs queued by the concurrency limit middleware.')
          @queue_size_metric.set({ worker: worker.name, feature_category: worker.get_feature_category }, queue_size)
        end

        def report_concurrent_workers(worker, concurrent_worker_count)
          @concurrency_metric ||= Gitlab::Metrics.gauge(:sidekiq_concurrency_limit_current_concurrent_jobs,
            'Current number of concurrent running jobs.')
          @concurrency_metric.set({ worker: worker.name, feature_category: worker.get_feature_category },
            concurrent_worker_count)
        end

        def report_max_limit(worker, limit)
          @limit_metric ||= Gitlab::Metrics.gauge(:sidekiq_concurrency_limit_max_concurrent_jobs,
            'Max number of concurrent running jobs.')
          @limit_metric.set({ worker: worker.name, feature_category: worker.get_feature_category }, limit)
        end

        def report_current_limit(worker, limit)
          @current_limit_metric ||= Gitlab::Metrics.gauge(:sidekiq_concurrency_limit_current_limit,
            'Number of concurrent jobs currently allowed to run subject to throttling.')
          @current_limit_metric.set({ worker: worker.name, feature_category: worker.get_feature_category }, limit)
        end

        def report_override_limit(worker, limit)
          @override_limit_metric ||= Gitlab::Metrics.gauge(:sidekiq_concurrency_limit_override_limit,
            'Operator override of the concurrency limit. Zero when no override is active.')
          @override_limit_metric.set({ worker: worker.name, feature_category: worker.get_feature_category }, limit)
        end
      end
    end
  end
end
