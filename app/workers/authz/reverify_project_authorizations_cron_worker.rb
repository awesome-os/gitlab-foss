# frozen_string_literal: true

module Authz
  class ReverifyProjectAuthorizationsCronWorker
    include ApplicationWorker
    include LoopWithRuntimeLimit
    include CronjobChildWorker
    include LimitedCapacity::Worker
    include Authz::UserRefreshLock

    data_consistency :sticky
    feature_category :permissions
    idempotent!
    defer_on_database_health_signal :gitlab_main_org, [], 5.minutes,
      indicators: Gitlab::Database::HealthStatus::GLOBAL_INDICATORS

    MAX_RUNNING_JOBS = 4
    INCREASED_MAX_RUNNING_JOBS = 10
    MAX_RUNTIME = 200.seconds

    def self.defer_on_database_health_signal?
      Feature.enabled?(:defer_safety_net_auth_refresh_on_wal_rate, :instance)
    end

    def perform_work
      return if Feature.enabled?(:do_not_run_safety_net_auth_refresh_jobs, :instance)

      users_processed = 0
      queue_lag_s = nil

      result = loop_with_runtime_limit(MAX_RUNTIME) do
        batch = Authz::ProjectAuthorizationReverification.claim_batch
        break :complete if batch.empty?

        queue_lag_s ||= lag_seconds(batch)

        batch.each do |reverification|
          users_processed += 1 if process(reverification)
        end
      end

      queue_drained = result == :complete &&
        !Authz::ProjectAuthorizationReverification.to_be_processed.exists?

      log_extra_metadata_on_done(:users_processed, users_processed)
      log_extra_metadata_on_done(:queue_drained, queue_drained)
      log_extra_metadata_on_done(:queue_lag_s, queue_lag_s || 0)
    end

    def remaining_work_count
      return 0 if Feature.enabled?(:do_not_run_safety_net_auth_refresh_jobs, :instance)

      Authz::ProjectAuthorizationReverification.to_be_processed.limit(max_running_jobs + 1).count
    end

    def max_running_jobs
      if Feature.enabled?(:increased_reverify_project_authorizations_capacity, :instance)
        INCREASED_MAX_RUNNING_JOBS
      else
        MAX_RUNNING_JOBS
      end
    end

    private

    def lag_seconds(batch)
      processed_at = batch.map(&:enqueued_at).min + Authz::ProjectAuthorizationReverification::MIN_AGE

      (Time.current - processed_at).round
    end

    def process(reverification)
      refresh_authorizations(reverification.user)
      reverification.processed

      true
    rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
      Authz::ProjectAuthorizationReverification.queue_users([reverification.user_id])

      false
    rescue StandardError => e
      Gitlab::ErrorTracking.track_exception(e, user_id: reverification.user_id)

      false
    end

    def refresh_authorizations(user)
      return unless user

      Gitlab::ApplicationContext.with_raw_context(
        authorized_projects_refresh_purpose: UserProjectAccessChangedService::SAFETY_NET_REFRESH_PURPOSE
      ) do
        with_context(user: user, related_class: self.class.name) do
          service = Users::RefreshAuthorizedProjectsService.new(user, source: self.class.name)

          with_user_refresh_lock(user) { service.execute }
        end
      end
    end
  end
end
