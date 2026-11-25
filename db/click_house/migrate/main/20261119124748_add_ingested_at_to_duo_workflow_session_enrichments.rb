# frozen_string_literal: true

# Not DEFAULT now64(): parts written before this column evaluate the default on every
# read, so old rows would look freshly ingested forever. Inserts must set the value.
class AddIngestedAtToDuoWorkflowSessionEnrichments < ClickHouse::Migration
  def up
    execute <<~SQL
    ALTER TABLE duo_workflow_session_enrichments
      ADD COLUMN IF NOT EXISTS ingested_at DateTime64(6, 'UTC') DEFAULT updated_at CODEC(Delta(8), ZSTD(1))
      AFTER updated_at;
    SQL
  end

  def down
    execute <<~SQL
    ALTER TABLE duo_workflow_session_enrichments
      DROP COLUMN IF EXISTS ingested_at;
    SQL
  end
end
