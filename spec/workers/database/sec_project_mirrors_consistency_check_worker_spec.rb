# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Database::SecProjectMirrorsConsistencyCheckWorker, feature_category: :cell do
  let(:worker) { described_class.new }

  let(:backfill_status) { :finished }

  before do
    create(:batched_background_migration, backfill_status,
      job_class_name: 'BackfillSecProjectMirrors', table_name: :projects, column_name: :id,
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

    it 'executes the consistency check on projects' do
      expect(Database::ConsistencyCheckService).to receive(:new).and_call_original
      expected_result = { batches: 0, matches: 0, mismatches: 0, mismatches_details: [] }
      expect(worker).to receive(:log_extra_metadata_on_done).with(:results, expected_result)
      worker.perform
    end

    context 'when logs should contain the detailed mismatches' do
      let(:first_project) { Project.all.order(:id).limit(1).first }
      let(:missing_project) { Project.all.order(:id).limit(2).last }

      before do
        redis_shared_state_cleanup!
        create_list(:project, 3)
        # The project factory only simulates ::Projects::ProcessSyncEventsWorker for the ci mirror.
        Project.find_each { |project| create(:security_project_mirror, project: project) }
        missing_project.delete

        allow_next_instance_of(Database::ConsistencyCheckService) do |instance|
          allow(instance).to receive(:random_start_id).and_return(Project.first.id)
        end
      end

      it 'reports the differences to the logs' do
        expected_result = {
          batches: 1,
          matches: 2,
          mismatches: 1,
          mismatches_details: [{
            id: missing_project.id,
            source_table: nil,
            target_table: [missing_project.namespace_id, missing_project.organization_id]
          }],
          start_id: first_project.id,
          next_start_id: first_project.id # The batch size > number of projects
        }
        expect(worker).to receive(:log_extra_metadata_on_done).with(:results, expected_result)
        worker.perform
      end

      it 'calls the consistency_fix_service to fix the inconsistencies' do
        expect_next_instance_of(Database::ConsistencyFixService) do |instance|
          expect(instance).to receive(:execute).with(
            ids: [missing_project.id]
          ).and_call_original
        end
        worker.perform
      end

      it 'deletes the orphaned mirror and leaves the other mirrors alone' do
        expect { worker.perform }
          .to change { Security::ProjectMirror.where(project_id: missing_project.id).count }.from(1).to(0)
          .and not_change { Projects::SyncEvent.count }

        expect(Security::ProjectMirror.pluck(:project_id)).to match_array(Project.pluck(:id))
      end

      it_behaves_like 'an idempotent worker' do
        it 'deletes the orphaned mirror once and keeps the result stable' do
          perform_idempotent_work

          expect(Security::ProjectMirror.pluck(:project_id)).to match_array(Project.pluck(:id))
        end
      end
    end

    context 'when a mirror column has drifted from the project' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:project) { create(:project) }
      let_it_be(:other_namespace) { create(:namespace) }
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:security_project_mirror) { create(:security_project_mirror, project: project) }

      let(:synced_columns) { %w[namespace_id organization_id] }

      where(:column, :stale_value) do
        :namespace_id    | lazy { other_namespace.id }
        :organization_id | lazy { other_organization.id }
      end

      with_them do
        before do
          redis_shared_state_cleanup!
          Security::ProjectMirror.where(project_id: project.id).update_all(column => stale_value)

          allow_next_instance_of(Database::ConsistencyCheckService) do |instance|
            allow(instance).to receive(:random_start_id).and_return(project.id)
          end
        end

        it 'reports the mismatch and schedules a resync' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(
            :results,
            a_hash_including(
              mismatches: 1,
              mismatches_details: [{
                id: project.id,
                source_table: project.attributes.values_at(*synced_columns),
                target_table: project.attributes.merge(column.to_s => stale_value).values_at(*synced_columns)
              }]
            )
          )

          expect { worker.perform }.to change { Projects::SyncEvent.where(project_id: project.id).count }.by(1)
        end
      end
    end
  end
end
