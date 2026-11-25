# frozen_string_literal: true

module Authz
  module ProjectAuthorizations
    # Drains authz_refresh_events. The cron run each minute queues the polling slot, which takes new events and
    # waits on an empty queue until its runtime limit, so they wait about a second. When there's more work, slots
    # start others, which exit once they find nothing to take, so an idle queue holds one thread. Correctness
    # doesn't depend on how many run.
    class RefreshWorker # rubocop:disable Sidekiq/EnforceDatabaseHealthSignalDeferral -- runs fewer slots while the database is unhealthy instead; a full stop would delay revoking access
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- RefreshService sets the context for each lease

      data_consistency :sticky
      feature_category :permissions
      urgency :low
      idempotent!
      # Until executed, so a polling slot can't overlap itself; rescheduling once restarts it right after it ends
      # instead of at the next cron run.
      deduplicate :until_executed, if_deduplicated: :reschedule_once
      concurrency_limit -> { SLOTS }

      MAX_RUNTIME = 4.minutes
      POLL_INTERVAL = 1.second
      SLOTS = 32
      # The most slots that run while the database is unhealthy. Fewer slots ease the load, but the queue keeps
      # moving so removed access is still revoked.
      STRESSED_SLOTS = SLOTS / 2
      POLLING_SLOT = 1
      HEALTH_CACHE_KEY = 'authz_project_authorizations_refresh_database_unhealthy'
      HEALTH_CACHE_TTL = 30.seconds

      # @param workers [Integer] how many leases to run at once, besides the polling slot's
      # @note Deduplication keeps one job per slot; a running one reruns once after it ends.
      # @return [Boolean] whether an unhealthy database held it to STRESSED_SLOTS
      def self.scale_up(workers)
        last_slot = [POLLING_SLOT + workers, SLOTS].min
        capped = last_slot > STRESSED_SLOTS && database_unhealthy?
        last_slot = STRESSED_SLOTS if capped
        bulk_perform_async(((POLLING_SLOT + 1)..last_slot).map { |n| [n] }) if last_slot > POLLING_SLOT
        capped
      end

      # @note Cached, since indicators can query Prometheus.
      # @return [Boolean]
      def self.database_unhealthy?
        Rails.cache.fetch(HEALTH_CACHE_KEY, expires_in: HEALTH_CACHE_TTL) do
          context = Gitlab::Database::HealthStatus::Context.new(
            Gitlab::SidekiqMiddleware::SkipJobs::DatabaseHealthStatusChecker.new(nil, name),
            Gitlab::Database.schemas_to_base_models[:gitlab_main_org].first.connection,
            []
          )

          Gitlab::Database::HealthStatus.evaluate(context, Gitlab::Database::HealthStatus::GLOBAL_INDICATORS)
            .any?(&:stop?)
        end
      end

      # @param slot [Integer, nil] nil for the cron run, which queues the polling slot. Deduplication keeps at
      #   most one job per slot queued or running.
      def perform(slot = nil)
        return self.class.perform_async(POLLING_SLOT) unless slot

        # Slots queued before the database became unhealthy would otherwise run above STRESSED_SLOTS.
        if slot > STRESSED_SLOTS && self.class.database_unhealthy?
          return log_extra_metadata_on_done(:database_unhealthy, true)
        end

        poll_interval = POLL_INTERVAL if slot == POLLING_SLOT
        result = RefreshService.new(Gitlab::Metrics::RuntimeLimiter.new(MAX_RUNTIME), poll_interval: poll_interval)
          .execute

        result.payload.each { |key, value| log_extra_metadata_on_done(key, value) }
      end
    end
  end
end
