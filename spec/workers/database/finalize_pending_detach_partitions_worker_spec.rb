# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Database::FinalizePendingDetachPartitionsWorker, feature_category: :database do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    it 'finalizes pending detach partitions' do
      expect(Gitlab::Database::Partitioning).to receive(:finalize_pending_detach_partitions)

      perform
    end
  end
end
