# frozen_string_literal: true

class BackfillSprintsForBigintConversion < Gitlab::Database::Migration[2.4]
  restrict_gitlab_migration gitlab_schema: :gitlab_main_org
  milestone '19.7'

  TABLE = :sprints
  COLUMNS = %i[iterations_cadence_id]

  # Most updated rows write to every index on sprints, including a gist exclusion index,
  # so a 1000-row sub-batch takes about 200ms. 500 keeps each update near 100ms.
  SUB_BATCH_SIZE = 500

  def up
    backfill_conversion_of_integer_to_bigint(TABLE, COLUMNS, sub_batch_size: SUB_BATCH_SIZE)
  end

  def down
    revert_backfill_conversion_of_integer_to_bigint(TABLE, COLUMNS)
  end
end
