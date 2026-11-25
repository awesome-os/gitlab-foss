# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe BackfillSprintsForBigintConversion, migration: :gitlab_main_org, feature_category: :team_planning do
  let(:batched_migration) { 'CopyColumnUsingBackgroundMigrationJob' }

  it 'schedules the backfill of the bigint column' do
    reversible_migration do |migration|
      migration.before -> {
        expect(batched_migration).not_to have_scheduled_batched_migration
      }

      migration.after -> {
        expect(batched_migration).to have_scheduled_batched_migration(
          gitlab_schema: :gitlab_main_org,
          table_name: :sprints,
          column_name: :id,
          job_arguments: [%w[iterations_cadence_id], %w[iterations_cadence_id_convert_to_bigint]],
          sub_batch_size: described_class::SUB_BATCH_SIZE
        )
      }
    end
  end
end
