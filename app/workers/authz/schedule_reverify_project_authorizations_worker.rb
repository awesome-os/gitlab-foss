# frozen_string_literal: true

module Authz
  class ScheduleReverifyProjectAuthorizationsWorker
    include ApplicationWorker
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- only schedules the child worker, which sets the user context

    data_consistency :sticky
    feature_category :permissions
    idempotent!
    deduplicate :until_executing

    def perform
      schedule_reverification unless Feature.enabled?(:do_not_run_safety_net_auth_refresh_jobs, :instance)
      verify_sample
    end

    private

    def schedule_reverification
      requeue_abandoned
      return unless Authz::ProjectAuthorizationReverification.to_be_processed.pick(:id)

      Authz::ReverifyProjectAuthorizationsCronWorker.perform_with_capacity
    end

    def requeue_abandoned
      Authz::ProjectAuthorizationReverification.abandoned.each_batch do |batch|
        batch.update_all(status: :pending, refresh_started_at: nil)
      end
    end

    # @note Runs after scheduling, so the safety net doesn't wait for it, and while the safety net is switched off.
    def verify_sample
      return unless Feature.enabled?(:authz_refresh_verifier, :instance)

      Authz::ProjectAuthorizations::VerifyService.new.execute.payload.each do |outcome, count|
        log_extra_metadata_on_done(:"verifier_#{outcome}", count)
      end
    rescue StandardError => e
      # The verifier only reports, so its failure mustn't fail the job.
      Gitlab::ErrorTracking.track_exception(e)
    end
  end
end
