# frozen_string_literal: true

module Import
  module Offline
    module Exports
      class FailStaleService
        STALE_ERROR_MESSAGE = 'Export timed out due to inactivity'
        RELATION_BATCH_SIZE = 1000
        EXPORT_BATCH_SIZE = 1000
        FINALIZATION_RETRY_WINDOW = 24.hours

        def execute
          cutoff = Import::Offline::Export::STALE_AFTER.ago
          scope = Import::Offline::Export.stale_candidates(cutoff).order_by_updated_at_and_id(:asc)
          failed_count = 0
          scheduled_count = 0
          error_count = 0

          # Keep the cursor separate from records whose updated_at changes when failed.
          Gitlab::Pagination::Keyset::Iterator.new(scope: scope).each_batch(load_batch: false) do |exports|
            exports.including_user_and_organization.each do |export|
              result = fail_if_stale(export, cutoff)
              failed_count += 1 if result == :failed
              scheduled_count += 1 if result == :scheduled
              error_count += 1 if result == :error
            end
          end

          ServiceResponse.success(payload: {
            failed_count: failed_count, scheduled_count: scheduled_count, error_count: error_count
          })
        end

        private

        def fail_if_stale(export, cutoff)
          Gitlab::ApplicationContext.with_context(organization: export.organization, user: export.user) do
            result = export.with_lock do
              next unless export.stale?(cutoff)

              fail_relation_exports(export)
              fail_export = export.created? || export.stale?(cutoff - FINALIZATION_RETRY_WINDOW)
              export.fail_op! if fail_export

              Gitlab::Export::Logger.error(
                Labkit::Fields::CLASS_NAME => self.class.name,
                message: 'Offline export stale',
                offline_export_id: export.id
              )

              fail_export ? :failed : :finalize
            end

            if result == :finalize
              Import::Offline::ExportWorker.perform_async(export.id)
              :scheduled
            else
              result
            end
          end
        rescue StandardError => exception
          Gitlab::ErrorTracking.track_exception(exception, offline_export_id: export.id)
          :error
        end

        def fail_relation_exports(offline_export)
          failure_attributes = { error: STALE_ERROR_MESSAGE, updated_at: Time.current }
          failed_count = 0

          ::BulkImports::Export.for_offline_export_in_progress(offline_export)
            .each_batch(of: RELATION_BATCH_SIZE) do |batch|
            ::BulkImports::ExportBatch.for_exports(batch).in_progress
              .each_batch(of: EXPORT_BATCH_SIZE) do |export_batches|
              export_batches.fail_stale!(**failure_attributes)
            end
            failed_count += batch.fail_stale!(**failure_attributes)
          end

          offline_export.update_has_failures! if failed_count > 0
        end
      end
    end
  end
end
