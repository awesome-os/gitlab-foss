# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Database::SecNamespaceMirrorsConsistencyCheckWorker, feature_category: :cell do
  let(:worker) { described_class.new }

  let(:backfill_status) { :finished }

  before do
    create(:batched_background_migration, backfill_status,
      job_class_name: 'BackfillSecNamespaceMirrors', table_name: :namespaces, column_name: :id,
      job_arguments: [], gitlab_schema: :gitlab_main_org)
  end

  describe '#perform' do
    context 'with the backfill in each state' do
      using RSpec::Parameterized::TableSyntax

      where(:backfill_status, :expected_runs) do
        :paused     | 0
        :active     | 0
        :failed     | 0
        :finalizing | 0
        :finished   | 1
        :finalized  | 1
      end

      with_them do
        it 'runs the consistency check only once the backfill is done' do
          expect(Database::ConsistencyCheckService).to receive(:new).exactly(expected_runs).times.and_call_original

          worker.perform
        end
      end
    end

    context 'when the backfill was never queued, as on a fresh install' do
      before do
        Gitlab::Database::BackgroundMigration::BatchedMigration.delete_all
      end

      it 'runs the consistency check' do
        expect(Database::ConsistencyCheckService).to receive(:new).and_call_original
        worker.perform
      end
    end

    it 'executes the consistency check on namespaces' do
      expect(Database::ConsistencyCheckService).to receive(:new).and_call_original
      expected_result = { batches: 0, matches: 0, mismatches: 0, mismatches_details: [] }
      expect(worker).to receive(:log_extra_metadata_on_done).with(:results, expected_result)
      worker.perform
    end

    context 'when logs should contain the detailed mismatches' do
      let(:first_namespace) { Namespace.all.order(:id).limit(1).first }
      let(:missing_namespace) { Namespace.all.order(:id).limit(2).last }

      before do
        redis_shared_state_cleanup!
        create_list(:namespace, 3)
        # The namespace factory only simulates ::Namespaces::ProcessSyncEventsWorker for the ci mirror.
        Namespace.find_each { |namespace| create(:security_namespace_mirror, namespace: namespace) }
        missing_namespace.delete

        allow_next_instance_of(Database::ConsistencyCheckService) do |instance|
          allow(instance).to receive(:random_start_id).and_return(Namespace.first.id)
        end
      end

      it 'reports the differences to the logs' do
        expected_result = {
          batches: 1,
          matches: 2,
          mismatches: 1,
          mismatches_details: [{
            id: missing_namespace.id,
            source_table: nil,
            target_table: [missing_namespace.traversal_ids, missing_namespace.organization_id]
          }],
          start_id: first_namespace.id,
          next_start_id: first_namespace.id # The batch size > number of namespaces
        }
        expect(worker).to receive(:log_extra_metadata_on_done).with(:results, expected_result)
        worker.perform
      end

      it 'calls the consistency_fix_service to fix the inconsistencies' do
        expect_next_instance_of(Database::ConsistencyFixService) do |instance|
          expect(instance).to receive(:execute).with(
            ids: [missing_namespace.id]
          ).and_call_original
        end
        worker.perform
      end

      it 'deletes the orphaned mirror and leaves the other mirrors alone' do
        expect { worker.perform }
          .to change { Security::NamespaceMirror.where(namespace_id: missing_namespace.id).count }.from(1).to(0)
          .and not_change { Namespaces::SyncEvent.count }

        expect(Security::NamespaceMirror.pluck(:namespace_id)).to match_array(Namespace.pluck(:id))
      end

      it_behaves_like 'an idempotent worker' do
        it 'deletes the orphaned mirror once and keeps the result stable' do
          perform_idempotent_work

          expect(Security::NamespaceMirror.pluck(:namespace_id)).to match_array(Namespace.pluck(:id))
        end
      end
    end

    context 'when a mirror column has drifted from the namespace' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:security_namespace_mirror) { create(:security_namespace_mirror, namespace: namespace) }

      let(:synced_columns) { %w[traversal_ids organization_id] }

      # organization_id is NOT NULL on sec_namespace_mirrors, so a NULL value cannot be stored.
      where(:column, :stale_value) do
        :traversal_ids   | []
        :organization_id | lazy { other_organization.id }
      end

      with_them do
        before do
          redis_shared_state_cleanup!
          Security::NamespaceMirror.where(namespace_id: namespace.id).update_all(column => stale_value)

          allow_next_instance_of(Database::ConsistencyCheckService) do |instance|
            allow(instance).to receive(:random_start_id).and_return(namespace.id)
          end
        end

        it 'reports the mismatch and schedules a resync' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(
            :results,
            a_hash_including(
              mismatches: 1,
              mismatches_details: [{
                id: namespace.id,
                source_table: namespace.attributes.values_at(*synced_columns),
                target_table: namespace.attributes.merge(column.to_s => stale_value).values_at(*synced_columns)
              }]
            )
          )

          expect { worker.perform }.to change { Namespaces::SyncEvent.where(namespace_id: namespace.id).count }.by(1)
        end
      end
    end
  end
end
