# frozen_string_literal: true

module Database # rubocop:disable Gitlab/BoundedContexts -- existing module that holds the related consistency check/fix services
  class SecProjectMirrorsConsistencyCheckWorker
    include ApplicationWorker
    include CronjobQueue # rubocop: disable Scalability/CronWorkerContext -- scans every project, so no single context applies

    sidekiq_options retry: false
    feature_category :cell
    data_consistency :sticky
    idempotent!

    version 1

    BACKFILL_MIGRATION = 'BackfillSecProjectMirrors'

    def perform
      # Every project is a mismatch until the backfill populates the mirror.
      return unless backfill_finished?

      results = ConsistencyCheckService.new(
        source_model: Project,
        target_model: Security::ProjectMirror,
        source_columns: %w[id namespace_id organization_id],
        target_columns: %w[project_id namespace_id organization_id]
      ).execute

      if results[:mismatches_details].any?
        ConsistencyFixService.new(
          source_model: Project,
          target_model: Security::ProjectMirror,
          sync_event_class: Projects::SyncEvent,
          source_sort_key: :id,
          target_sort_key: :project_id
        ).execute(ids: results[:mismatches_details].map { |detail| detail.fetch(:id) })
      end

      log_extra_metadata_on_done(:results, results)
    end

    private

    def backfill_finished?
      migration = Gitlab::Database::BackgroundMigration::BatchedMigration.find_for_configuration(
        :gitlab_main_org, BACKFILL_MIGRATION, :projects, :id, []
      )
      # No record means a fresh install, which loads the schema instead of migrating
      # and so has nothing to backfill.
      return true unless migration

      migration.finished? || migration.finalized?
    end
  end
end
