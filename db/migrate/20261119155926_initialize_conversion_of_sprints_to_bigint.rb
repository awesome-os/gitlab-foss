# frozen_string_literal: true

class InitializeConversionOfSprintsToBigint < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  TABLE = :sprints
  COLUMNS = %i[iterations_cadence_id]

  def up
    initialize_conversion_of_integer_to_bigint(TABLE, COLUMNS)
  end

  def down
    revert_initialize_conversion_of_integer_to_bigint(TABLE, COLUMNS)
  end
end
