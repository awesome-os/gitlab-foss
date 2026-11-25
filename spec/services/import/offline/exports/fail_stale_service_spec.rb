# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::Offline::Exports::FailStaleService, :freeze_time, :clean_gitlab_redis_shared_state,
  feature_category: :importers do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let(:status) { :started }
  let(:updated_at) { 3.days.ago }
  let!(:offline_export) do
    create(:offline_export, status, :with_configuration, user: user, organization: group.organization,
      created_at: 3.days.ago, updated_at: updated_at)
  end

  subject(:execute_service) { described_class.new.execute }

  describe '#execute' do
    it 'returns zero totals when there are no candidates', :aggregate_failures do
      offline_export.update!(updated_at: Time.current)

      response = execute_service

      expect(response).to be_success
      expect(response.payload).to eq(failed_count: 0, scheduled_count: 0, error_count: 0)
    end

    context 'when the export has no relation exports' do
      where(:status) { %i[created started] }

      with_them do
        it 'fails the stale export' do
          expect { execute_service }.to change { offline_export.reload.status_name }.from(status).to(:failed)
          expect(offline_export.has_failures?).to be(false)
        end
      end
    end

    context 'when polling stopped after relation exports completed' do
      let(:activity_at) { 25.hours.ago }
      let!(:relation_export) do
        create(:bulk_import_export, :finished, group: group, offline_export: offline_export,
          created_at: 3.days.ago, updated_at: activity_at)
      end

      it 're-enqueues finalization without changing activity or counting a failure', :aggregate_failures do
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id)
        expect(Notify).not_to receive(:offline_export_failed)
        expect(Import::Offline::ConfigurationPurgeWorker).not_to receive(:perform_in)

        response = execute_service

        expect(offline_export.reload).to have_attributes(status_name: :started, updated_at: updated_at)
        expect(relation_export.reload).to have_attributes(status_name: :finished, updated_at: activity_at)
        expect(response.payload).to eq(failed_count: 0, scheduled_count: 1, error_count: 0)
      end

      it 'uses the existing worker to write metadata and finish the export', :aggregate_failures do
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id)
        expect_next_instance_of(Import::Offline::Exports::WriteMetadataService, offline_export) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end
        mail = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
        expect(Notify).to receive(:offline_export_complete).with(user.id, offline_export.id).and_return(mail)
        expect(Notify).not_to receive(:offline_export_failed)

        execute_service
        Import::Offline::ExportWorker.new.perform(offline_export.id)

        expect(offline_export.reload).to be_finished
      end

      it 'also retries exports with a mixture of finished and failed relations' do
        create(:bulk_import_export, :failed, group: group, relation: 'milestones', offline_export: offline_export,
          created_at: 3.days.ago, updated_at: activity_at)
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id)

        expect { execute_service }.not_to change { offline_export.reload.status_name }
      end

      it 'allows recovery based on parent activity when relations completed earlier' do
        relation_export.update!(updated_at: 3.days.ago)
        offline_export.update!(updated_at: activity_at)
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id)

        expect { execute_service }.not_to change { offline_export.reload.status_name }
      end

      it 'fails after the recovery window even when re-enqueued jobs keep getting lost', :aggregate_failures do
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id).exactly(6).times
        mail = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
        expect(Notify).to receive(:offline_export_failed).with(user.id, offline_export.id).and_return(mail)

        6.times do
          described_class.new.execute
          expect(offline_export.reload).to be_started
          travel 4.hours
        end
        response = described_class.new.execute

        expect(offline_export.reload).to be_failed
        expect(relation_export.reload).to be_finished
        expect(response.payload).to eq(failed_count: 1, scheduled_count: 0, error_count: 0)
      end

      it 'tracks an enqueue error and leaves the export available for another recovery attempt', :aggregate_failures do
        error = StandardError.new('Unable to enqueue finalization')
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id).and_raise(error)
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error, offline_export_id: offline_export.id)

        response = execute_service

        expect(offline_export.reload).to have_attributes(status_name: :started, updated_at: updated_at)
        expect(response.payload).to eq(failed_count: 0, scheduled_count: 0, error_count: 1)
      end

      it 'bounds recovery after cleaning up stalled relations', :aggregate_failures do
        stalled_relation = create(:bulk_import_export, :started, group: group, relation: 'milestones',
          offline_export: offline_export, created_at: 3.days.ago, updated_at: activity_at)
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id).once

        described_class.new.execute
        expect(offline_export.reload).to be_started
        travel 49.hours
        response = described_class.new.execute

        expect(offline_export.reload).to be_failed
        expect(stalled_relation.reload).to be_failed
        expect(relation_export.reload).to be_finished
        expect(response.payload).to eq(failed_count: 1, scheduled_count: 0, error_count: 0)
      end

      it 'lets the existing worker fail an export when every relation failed', :aggregate_failures do
        relation_export.update_columns(status: BulkImports::Export::FAILED)
        expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id)
        expect(Import::Offline::Exports::WriteMetadataService).not_to receive(:new)

        execute_service
        expect(offline_export.reload).to be_started

        Import::Offline::ExportWorker.new.perform(offline_export.id)

        expect(offline_export.reload).to be_failed
      end

      context 'when a relation is still in progress' do
        where(:relation_status) { %i[pending started] }

        with_them do
          it 'finishes with failures after failing the stalled relation', :aggregate_failures do
            stalled_relation = create(:bulk_import_export, relation_status, group: group, relation: 'milestones',
              offline_export: offline_export, created_at: 3.days.ago, updated_at: activity_at)
            expect(Import::Offline::ExportWorker).to receive(:perform_async).with(offline_export.id)

            response = execute_service

            expect(offline_export.reload).to be_started
            expect(response.payload).to eq(failed_count: 0, scheduled_count: 1, error_count: 0)
            perform_finalization

            expect(offline_export.reload).to have_attributes(status_name: :finished, has_failures: true)
            expect(stalled_relation.reload).to be_failed
            expect(relation_export.reload).to be_finished
          end
        end
      end

      context 'when the export has not started' do
        let(:status) { :created }

        it 'fails instead of restarting processing' do
          expect(Import::Offline::ExportWorker).not_to receive(:perform_async)

          expect { execute_service }.to change { offline_export.reload.status_name }.from(:created).to(:failed)
        end
      end

      context 'when the recovery window has already elapsed' do
        let(:activity_at) { (48.hours + 1.second).ago }

        it 'fails without re-enqueuing finalization' do
          expect(Import::Offline::ExportWorker).not_to receive(:perform_async)

          expect { execute_service }.to change { offline_export.reload.status_name }.from(:started).to(:failed)
        end
      end
    end

    it 'fails unfinished relations and preserves completed relations', :aggregate_failures do
      expect(Notify).not_to receive(:offline_export_failed)

      relations = {
        pending: 'labels',
        started: 'milestones',
        finished: 'badges',
        failed: 'members'
      }.map do |relation_status, relation|
        create(:bulk_import_export, relation_status, group: group, relation: relation, offline_export: offline_export,
          created_at: 3.days.ago, updated_at: 3.days.ago)
      end

      execute_service
      perform_finalization

      expect(offline_export.reload).to be_finished
      expect(offline_export.has_failures?).to be(true)
      expect(relations.map { |relation| relation.reload.status_name }).to eq(%i[failed failed finished failed])
      expect(relations.first(2).map(&:error)).to all(eq(described_class::STALE_ERROR_MESSAGE))
      expect(relations.first(2).map(&:updated_at)).to all(eq(Time.current))
      expect(relations.last(2).map(&:error)).to all(be_nil)
      expect(relations.last(2).map(&:updated_at)).to all(eq(3.days.ago))
    end

    it 'fails unfinished batches and preserves completed batches', :aggregate_failures do
      relation_export = create(:bulk_import_export, :started, :batched, group: group, offline_export: offline_export,
        created_at: 3.days.ago, updated_at: 3.days.ago)
      batches = %i[created started finished failed].each_with_index.map do |batch_status, index|
        create(:bulk_import_export_batch, batch_status, export: relation_export, batch_number: index + 1,
          created_at: 3.days.ago, updated_at: 3.days.ago)
      end
      finished_relation = create(:bulk_import_export, :finished, :batched, group: group, relation: 'milestones',
        offline_export: offline_export, created_at: 3.days.ago, updated_at: 3.days.ago)
      preserved_batch = create(:bulk_import_export_batch, :created, export: finished_relation,
        created_at: 3.days.ago, updated_at: 3.days.ago)

      execute_service

      expect(batches.map { |batch| batch.reload.status_name }).to eq(%i[failed failed finished failed])
      expect(batches.first(2).map(&:error)).to all(eq(described_class::STALE_ERROR_MESSAGE))
      expect(batches.first(2).map(&:updated_at)).to all(eq(Time.current))
      expect(batches.last(2).map(&:error)).to all(be_nil)
      expect(batches.last(2).map(&:updated_at)).to all(eq(3.days.ago))
      expect(preserved_batch.reload).to be_created
      expect(preserved_batch.updated_at).to eq(3.days.ago)
      expect(relation_export.reload).to be_failed
      expect(offline_export.reload).to be_started
    end

    it 'bounds batch updates when one relation has more batches than the limit', :aggregate_failures do
      stub_const("#{described_class}::EXPORT_BATCH_SIZE", 2)
      relation_export = create(:bulk_import_export, :started, :batched, group: group, offline_export: offline_export,
        created_at: 3.days.ago, updated_at: 3.days.ago)
      batches = Array.new(5) do |index|
        create(:bulk_import_export_batch, index.even? ? :created : :started, export: relation_export,
          batch_number: index + 1, created_at: 3.days.ago, updated_at: 3.days.ago)
      end

      recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { execute_service }

      expect(recorder.log.grep(/UPDATE "bulk_import_export_batches"/).size).to eq(3)
      expect(recorder.log.grep(/UPDATE "bulk_import_exports"/).size).to eq(1)
      expect(batches.map(&:reload)).to all(
        have_attributes(status_name: :failed, error: described_class::STALE_ERROR_MESSAGE, updated_at: Time.current)
      )
      expect(relation_export.reload).to be_failed
      expect(offline_export.reload).to be_started
      expect(offline_export.has_failures?).to be(true)
    end

    it 'leaves unrelated direct transfer exports alone' do
      direct_transfer_export = create(:bulk_import_export, :started, group: group,
        created_at: 3.days.ago, updated_at: 3.days.ago)

      expect { execute_service }.not_to change { direct_transfer_export.reload.status_name }
    end

    context 'when the offline export was updated recently' do
      let(:updated_at) { 1.hour.ago }

      it 'preserves its status' do
        expect { execute_service }.not_to change { offline_export.reload.status_name }
      end
    end

    context 'when a relation export was updated recently' do
      where(:relation_status) { %i[pending started finished failed] }

      with_them do
        it 'preserves the offline export even when it started days ago' do
          relation_export = create(:bulk_import_export, relation_status, group: group,
            offline_export: offline_export, created_at: 3.days.ago, updated_at: 1.hour.ago)

          expect { execute_service }
            .to not_change { offline_export.reload.status_name }
            .and not_change { relation_export.reload.status_name }
        end
      end
    end

    context 'when the offline export has completed' do
      where(:status) { %i[finished failed] }

      with_them do
        it 'preserves its status without sending another email' do
          expect(Notify).not_to receive(:offline_export_failed)

          expect { execute_service }.not_to change { offline_export.reload.updated_at }
        end
      end
    end

    it 'logs each stale export' do
      expect(Gitlab::Export::Logger).to receive(:error).with(
        Labkit::Fields::CLASS_NAME => described_class.name,
        message: 'Offline export stale',
        offline_export_id: offline_export.id
      )

      execute_service
    end

    it 'sends the failure email and schedules configuration cleanup only once with export context' do
      create(:bulk_import_export, :started, group: group, offline_export: offline_export,
        created_at: 3.days.ago, updated_at: 3.days.ago)
      mail = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

      expect(Notify).to receive(:offline_export_failed).once
        .with(offline_export.user_id, offline_export.id).and_return(mail)
      expect(Import::Offline::ExportWorker).to receive(:perform_async).once.with(offline_export.id) do
        expect(Gitlab::ApplicationContext.current).to include(
          'meta.organization_id' => offline_export.organization_id,
          'meta.user' => user.username
        )
      end
      expect(Import::Offline::ConfigurationPurgeWorker).to receive(:perform_in).once
        .with(Import::Offline::Export::PURGE_CONFIGURATION_DELAY, offline_export.configuration.id)

      2.times do
        described_class.new.execute
        Import::Offline::ExportWorker.new.perform(offline_export.id)
      end
    end

    it 'processes all pages of stale exports', :aggregate_failures do
      other_exports = create_list(:offline_export, 2, :started, :with_configuration, user: user,
        organization: group.organization, created_at: 3.days.ago, updated_at: 3.days.ago)
      allow_next_instance_of(Gitlab::Pagination::Keyset::Iterator) do |iterator|
        allow(iterator).to receive(:each_batch).and_wrap_original do |method, **options, &block|
          method.call(**options, of: 2, &block)
        end
      end

      response = execute_service

      expect([offline_export, *other_exports].map(&:reload)).to all(be_failed)
      expect(response).to be_success
      expect(response.payload).to eq(failed_count: 3, scheduled_count: 0, error_count: 0)
    end

    it 'continues processing later exports and pages when one export raises', :aggregate_failures do
      error = StandardError.new('Failed to save offline export')
      other_exports = create_list(:offline_export, 2, :started, :with_configuration, user: user,
        organization: group.organization, created_at: 3.days.ago, updated_at: 49.hours.ago)
      allow_next_found_instance_of(Import::Offline::Export) do |export|
        allow(export).to receive(:fail_op!).and_wrap_original do |method|
          raise error if export.id == offline_export.id

          method.call
        end
      end
      allow_next_instance_of(Gitlab::Pagination::Keyset::Iterator) do |iterator|
        allow(iterator).to receive(:each_batch).and_wrap_original do |method, **options, &block|
          method.call(**options, of: 2, &block)
        end
      end
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error, offline_export_id: offline_export.id)

      response = execute_service

      expect(offline_export.reload).to be_started
      expect(other_exports.map(&:reload)).to all(be_failed)
      expect(response).to be_success
      expect(response.payload).to eq(failed_count: 2, scheduled_count: 0, error_count: 1)
    end

    it 'loads context associations once per processing batch', :aggregate_failures do
      other_exports = create_list(:offline_export, 2, :started, user: user, organization: group.organization,
        created_at: 3.days.ago, updated_at: 3.days.ago)
      [offline_export, *other_exports].each do |export|
        create(:bulk_import_export, :started, group: group, offline_export: export,
          created_at: 3.days.ago, updated_at: 1.hour.ago)
      end

      described_class.new.execute
      recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { execute_service }

      expect(recorder.log.grep(/FROM "users"/).size).to eq(1)
      expect(recorder.log.grep(/FROM "organizations"/).size).to eq(1)
    end

    context 'with multiple relation exports and batches' do
      where(:batch_size, :expected_updates) do
        6 | 1
        2 | 3
      end

      with_them do
        it 'fails relations and batches in bulk without loading portables', :aggregate_failures do
          stub_const("#{described_class}::RELATION_BATCH_SIZE", batch_size)
          groups = create_list(:group, 3, parent: group)
          projects = create_list(:project, 3, group: group)
          relation_exports = (groups + projects).map do |portable|
            portable_attributes = portable.is_a?(Project) ? { project: portable } : { group: portable }
            create(:bulk_import_export, :started, **portable_attributes, offline_export: offline_export,
              created_at: 3.days.ago, updated_at: 3.days.ago)
          end
          batches = relation_exports.map do |relation_export|
            create(:bulk_import_export_batch, :started, export: relation_export,
              created_at: 3.days.ago, updated_at: 3.days.ago)
          end

          recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { execute_service }

          expect(recorder.log.grep(/UPDATE "bulk_import_exports"/).size).to eq(expected_updates)
          expect(recorder.log.grep(/UPDATE "bulk_import_export_batches"/).size).to eq(expected_updates)
          expect(recorder.log.grep(/UPDATE "import_offline_exports".*"has_failures"/).size).to eq(1)
          expect(recorder.log.grep(/FROM "projects"/)).to be_empty
          expect(recorder.log.grep(/FROM "namespaces".*'Group'/)).to be_empty
          expect(relation_exports.map(&:reload)).to all(be_failed)
          expect(batches.map(&:reload)).to all(be_failed)
          expect(offline_export.reload).to be_started
          expect(offline_export.has_failures?).to be(true)
        end
      end
    end

    it 'rechecks records that completed after the candidate query', :aggregate_failures do
      allow_next_found_instance_of(Import::Offline::Export) do |export|
        allow(export).to receive(:with_lock).and_wrap_original do |method, &block|
          offline_export.finish!
          method.call(&block)
        end
      end

      response = execute_service

      expect(offline_export.reload).to be_finished
      expect(response.payload).to eq(failed_count: 0, scheduled_count: 0, error_count: 0)
    end

    it 'rolls back relation failures if flagging the offline export raises', :aggregate_failures do
      stub_const("#{described_class}::EXPORT_BATCH_SIZE", 2)
      relation_export = create(:bulk_import_export, :started, :batched, group: group, offline_export: offline_export,
        created_at: 3.days.ago, updated_at: 3.days.ago)
      batches = Array.new(3) do |index|
        create(:bulk_import_export_batch, :started, export: relation_export, batch_number: index + 1,
          created_at: 3.days.ago, updated_at: 3.days.ago)
      end
      error = StandardError.new('Failed to save offline export')
      allow_next_found_instance_of(Import::Offline::Export) do |export|
        allow(export).to receive(:update_has_failures!).and_raise(error)
      end
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error, offline_export_id: offline_export.id)

      execute_service

      expect(offline_export.reload).to be_started
      expect(offline_export.has_failures?).to be(false)
      expect(relation_export.reload).to be_started
      expect(relation_export.error).to be_nil
      expect(batches.map(&:reload)).to all(have_attributes(status_name: :started, error: nil))
    end
  end

  def perform_finalization
    allow_next_instance_of(Import::Offline::Exports::WriteMetadataService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.success)
    end

    Import::Offline::ExportWorker.new.perform(offline_export.id)
  end
end
