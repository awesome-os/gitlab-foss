# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::Offline::StaleExportWorker, feature_category: :importers do
  describe '#perform' do
    it_behaves_like 'an idempotent worker'

    it 'calls the service and logs the totals for the run' do
      response = ServiceResponse.success(payload: { failed_count: 2, scheduled_count: 3, error_count: 1 })
      expect_next_instance_of(Import::Offline::Exports::FailStaleService) do |service|
        expect(service).to receive(:execute).once.and_return(response)
      end
      worker = described_class.new
      expect(worker).to receive(:log_extra_metadata_on_done).with(:failed_count, 2)
      expect(worker).to receive(:log_extra_metadata_on_done).with(:scheduled_count, 3)
      expect(worker).to receive(:log_extra_metadata_on_done).with(:error_count, 1)

      worker.perform
    end

    it 'logs zero totals for an empty run' do
      worker = described_class.new
      expect(worker).to receive(:log_extra_metadata_on_done).with(:failed_count, 0)
      expect(worker).to receive(:log_extra_metadata_on_done).with(:scheduled_count, 0)
      expect(worker).to receive(:log_extra_metadata_on_done).with(:error_count, 0)

      worker.perform
    end
  end
end
