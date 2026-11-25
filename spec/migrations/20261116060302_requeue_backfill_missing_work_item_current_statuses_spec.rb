# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RequeueBackfillMissingWorkItemCurrentStatuses, migration: :gitlab_main_org, feature_category: :team_planning do
  let!(:batched_migration) { described_class::MIGRATION }

  let(:organization) { table(:organizations).create!(name: 'org', path: 'org') }
  let(:namespace) do
    table(:namespaces).create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

  let!(:issues) do
    Array.new(3) do
      table(:issues).create!(title: 'issue', namespace_id: namespace.id, work_item_type_id: 1, state_id: 1)
    end
  end

  def queue_previous_run(status:, max_id:)
    Gitlab::Database::BackgroundMigration::BatchedMigration.create!(
      job_class_name: described_class::MIGRATION, table_name: :issues, column_name: :id, job_arguments: [],
      interval: 2.minutes, min_cursor: [1], max_cursor: [max_id], batch_size: 10_000, sub_batch_size: 100,
      gitlab_schema: :gitlab_main_org,
      status: Gitlab::Database::BackgroundMigration::BatchedMigration.state_machines[:status].states[status].value
    )
  end

  def scheduled_cursors
    migration = Gitlab::Database::BackgroundMigration::BatchedMigration
      .find_for_configuration(:gitlab_main_org, described_class::MIGRATION, :issues, :id, [])

    [migration.min_cursor, migration.max_cursor]
  end

  %i[finished finalized].each do |status|
    context "when the first run is #{status}" do
      let(:previous_max_id) { issues.first.id }

      before do
        queue_previous_run(status: status, max_id: previous_max_id)
      end

      it 'queues the ids added since its range was fixed' do
        migrate!

        expect(scheduled_cursors).to eq([[issues.second.id], [issues.last.id]])
      end

      context 'when no issues were created since' do
        let(:previous_max_id) { issues.last.id }

        it 'queues an empty range' do
          migrate!

          expect(scheduled_cursors).to eq([[issues.last.id + 1], [issues.last.id]])
        end
      end

      context 'when the issues table is empty' do
        before do
          table(:issues).delete_all
        end

        it 'queues a finished migration' do
          migrate!

          migration = Gitlab::Database::BackgroundMigration::BatchedMigration
            .find_for_configuration(:gitlab_main_org, described_class::MIGRATION, :issues, :id, [])

          expect(migration).to be_finished
        end
      end
    end
  end

  context 'when the first run has not finished' do
    before do
      queue_previous_run(status: :active, max_id: issues.first.id)
    end

    it 'queues the whole table' do
      migrate!

      expect(scheduled_cursors).to eq([[issues.first.id], [issues.last.id]])
    end
  end

  context 'without a first run' do
    it 'schedules a new batched migration over the whole table' do
      reversible_migration do |migration|
        migration.before -> {
          expect(batched_migration).not_to have_scheduled_batched_migration
        }

        migration.after -> {
          expect(batched_migration).to have_scheduled_batched_migration(
            gitlab_schema: :gitlab_main_org,
            table_name: :issues,
            column_name: :id,
            batch_size: described_class::BATCH_SIZE,
            sub_batch_size: described_class::SUB_BATCH_SIZE
          )
          expect(scheduled_cursors).to eq([[issues.first.id], [issues.last.id]])
        }
      end
    end
  end
end
