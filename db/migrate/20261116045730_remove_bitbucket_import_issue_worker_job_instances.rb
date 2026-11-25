# frozen_string_literal: true

class RemoveBitbucketImportIssueWorkerJobInstances < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  DEPRECATED_JOB_CLASSES = %w[
    Gitlab::BitbucketImport::ImportIssueWorker
    Gitlab::BitbucketImport::ImportIssueNotesWorker
    Gitlab::BitbucketImport::Stage::ImportIssuesWorker
    Gitlab::BitbucketImport::Stage::ImportIssuesNotesWorker
  ].freeze

  def up
    sidekiq_remove_jobs(job_klasses: DEPRECATED_JOB_CLASSES)
  end

  def down
    # This migration removes any instances of deprecated workers and cannot be undone.
  end
end
