# frozen_string_literal: true

module Import
  module Offline
    class StaleExportWorker
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- Context is set per export in the service.

      idempotent!
      data_consistency :sticky
      feature_category :importers
      concurrency_limit -> { 1 }

      def perform
        result = Import::Offline::Exports::FailStaleService.new.execute

        log_extra_metadata_on_done(:failed_count, result.payload[:failed_count])
        log_extra_metadata_on_done(:scheduled_count, result.payload[:scheduled_count])
        log_extra_metadata_on_done(:error_count, result.payload[:error_count])
      end
    end
  end
end
