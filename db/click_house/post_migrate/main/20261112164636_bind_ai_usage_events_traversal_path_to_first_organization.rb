# frozen_string_literal: true

class BindAiUsageEventsTraversalPathToFirstOrganization < ClickHouse::Migration
  STAGING_TABLE = 'ai_usage_events_repair'
  # Organizations::Organization::DEFAULT_ORGANIZATION_ID; inlined so the migration stays frozen.
  ORGANIZATION_ID = 1
  BATCH_SIZE = 100_000
  PRIMARY_KEYS = %i[traversal_path event timestamp user_id].freeze
  COLUMNS = %i[user_id event timestamp namespace_path traversal_path extras].freeze
  SELECT_COLUMNS = [
    :user_id, :event, :timestamp, :namespace_path,
    Arel.sql("concat('#{ORGANIZATION_ID}/', namespace_path)"), :extras
  ].freeze

  # Rows without a namespace keep the sentinel.
  SENTINEL = "traversal_path = '0/' AND toUInt64OrZero(splitByChar('/', namespace_path)[1]) != 0"

  def up
    execute("DROP TABLE IF EXISTS #{STAGING_TABLE}")
    execute("CREATE TABLE IF NOT EXISTS #{STAGING_TABLE} AS ai_usage_events")

    stage_bound_rows
    attach_staged_partitions
    execute_when_idle("ALTER TABLE ai_usage_events DELETE WHERE #{SENTINEL}")

    execute("DROP TABLE IF EXISTS #{STAGING_TABLE}")
  end

  def down; end

  private

  def stage_bound_rows
    iterator = ClickHouse::TableIterator.new('ai_usage_events', primary_keys: PRIMARY_KEYS, connection: connection)

    iterator.each_range(of: BATCH_SIZE) do |scope, min_keys|
      # Sentinel rows lead the primary key order, so later ranges hold none.
      break if min_keys[:traversal_path] > '0/'

      query = scope.where(Arel::Nodes::Grouping.new(Arel.sql(SENTINEL))).select(*SELECT_COLUMNS)

      execute("INSERT INTO #{STAGING_TABLE} (#{COLUMNS.join(', ')}) #{query.to_sql}")
    end
  end

  def attach_staged_partitions
    partition_ids = connection
      .select("SELECT DISTINCT _partition_id AS partition_id FROM #{STAGING_TABLE}")
      .pluck('partition_id')

    partition_ids.each do |partition_id|
      execute("ALTER TABLE ai_usage_events ATTACH PARTITION ID '#{partition_id}' FROM #{STAGING_TABLE}")
    end
  end
end
