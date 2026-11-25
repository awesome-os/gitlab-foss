# frozen_string_literal: true

class RemoveOnboardingProgressTrackingWorkerJobInstances < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  DEPRECATED_JOB_CLASSES = %w[
    Onboarding::ProgressTrackingWorker
  ]

  def up
    sidekiq_remove_jobs(job_klasses: DEPRECATED_JOB_CLASSES)
  end

  def down
    # This migration removes any instances of deprecated workers and cannot be undone.
  end
end
