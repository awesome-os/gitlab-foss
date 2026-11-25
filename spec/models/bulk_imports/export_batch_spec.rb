# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::ExportBatch, feature_category: :importers do
  describe 'associations' do
    it { is_expected.to belong_to(:export) }
    it { is_expected.to have_one(:upload) }
  end

  describe 'validations' do
    subject { build(:bulk_import_export_batch) }

    it { is_expected.to validate_presence_of(:batch_number) }
    it { is_expected.to validate_uniqueness_of(:batch_number).scoped_to(:export_id) }
  end

  describe 'scopes' do
    describe '.for_exports' do
      it 'returns batches belonging to all exports in the supplied relation' do
        exports = create_list(:bulk_import_export, 2)
        batches = exports.map { |export| create(:bulk_import_export_batch, export: export) }
        create(:bulk_import_export_batch)
        selected_exports = BulkImports::Export.where(id: exports.map(&:id))

        expect(described_class.for_exports(selected_exports)).to match_array(batches)
      end

      it 'returns no batches for an empty export relation' do
        create(:bulk_import_export_batch)

        expect(described_class.for_exports(BulkImports::Export.none)).to be_empty
      end
    end

    describe '.in_progress' do
      it 'returns only batches that are in progress' do
        created = create(:bulk_import_export_batch, :created)
        started = create(:bulk_import_export_batch, :started)
        create(:bulk_import_export_batch, :finished)
        create(:bulk_import_export_batch, :failed)

        expect(described_class.in_progress).to contain_exactly(created, started)
      end
    end
  end

  describe '.fail_stale!', :freeze_time do
    it 'fails matching in-progress batches and returns the affected count', :aggregate_failures do
      export = create(:bulk_import_export, :started)
      created_batch = create(:bulk_import_export_batch, :created, export: export,
        batch_number: 1, updated_at: 3.days.ago)
      started_batch = create(:bulk_import_export_batch, :started, export: export,
        batch_number: 2, updated_at: 3.days.ago)
      finished_batch = create(:bulk_import_export_batch, :finished, export: export,
        batch_number: 3, updated_at: 3.days.ago)
      unrelated_batch = create(:bulk_import_export_batch, :started, updated_at: 3.days.ago)
      preserved_attributes = [finished_batch, unrelated_batch].map { |batch| batch.reload.attributes }
      failed_at = 1.hour.ago

      affected = described_class.for_exports(BulkImports::Export.where(id: export.id)).in_progress
        .fail_stale!(error: 'Export timed out', updated_at: failed_at)

      expect(affected).to eq(2)
      expect([created_batch, started_batch].map(&:reload)).to all(
        have_attributes(status_name: :failed, error: 'Export timed out', updated_at: failed_at)
      )
      expect([finished_batch, unrelated_batch].map { |batch| batch.reload.attributes }).to eq(preserved_attributes)
      expect(export.reload).to be_started
    end

    it 'returns zero for an empty scope' do
      expect(described_class.none.fail_stale!(error: 'Export timed out', updated_at: Time.current)).to eq(0)
    end
  end

  describe '.started_and_not_timed_out' do
    subject(:started_and_not_timed_out) { described_class.started_and_not_timed_out }

    let_it_be(:recently_started_export_batch) { create(:bulk_import_export_batch, :started, updated_at: 1.minute.ago) }
    let_it_be(:old_started_export_batch) { create(:bulk_import_export_batch, :started, updated_at: 2.hours.ago) }
    let_it_be(:recently_finished_export_batch) do
      create(:bulk_import_export_batch, :finished, updated_at: 1.minute.ago)
    end

    it 'returns records with status started, which were last updated less that 1 hour ago' do
      is_expected.to contain_exactly(recently_started_export_batch)
    end
  end
end
