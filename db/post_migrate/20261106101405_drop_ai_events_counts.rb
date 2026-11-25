# frozen_string_literal: true

class DropAiEventsCounts < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.6'

  TABLE_NAME = :ai_events_counts

  def up
    drop_detached_partitions

    with_lock_retries do
      drop_table TABLE_NAME, if_exists: true
    end
  end

  def down
    opts = {
      primary_key: [:id, :events_date],
      options: 'PARTITION BY RANGE (events_date)',
      if_not_exists: true
    }

    create_table TABLE_NAME, **opts do |t|
      t.bigserial :id, null: false
      t.date :events_date, null: false
      t.bigint :namespace_id
      t.bigint :user_id, null: false, index: true
      t.bigint :organization_id, null: false, index: true
      t.integer :event, limit: 2, null: false
      t.integer :total_occurrences, null: false, default: 0
    end

    add_index TABLE_NAME, [:events_date, :namespace_id, :event, :user_id],
      unique: true,
      include: [:total_occurrences],
      nulls_not_distinct: true,
      name: 'idx_ai_events_counts_unique_tuple',
      if_not_exists: true
  end

  private

  # @note Detached partitions not yet dropped by DropDetachedPartitionsWorker
  #   still use the parent's id sequence, so the parent can't be dropped while
  #   they exist. Their foreign keys go first to keep the locks small.
  def drop_detached_partitions
    detached_partitions.each do |partition|
      identifier = "#{partition['schema']}.#{partition['name']}"

      foreign_keys(partition['oid']).each do |fk_name|
        with_lock_retries do
          execute(
            "ALTER TABLE IF EXISTS #{quote_table_name(identifier)} " \
              "DROP CONSTRAINT IF EXISTS #{quote_table_name(fk_name)}"
          )
        end
      end

      with_lock_retries do
        drop_table identifier, if_exists: true
      end

      execute("DELETE FROM detached_partitions WHERE table_name = #{quote(partition['name'])}")
    end
  end

  def detached_partitions
    select_all(<<~SQL).to_a
      SELECT c.oid, n.nspname AS schema, c.relname AS name
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = '#{Gitlab::Database::DYNAMIC_PARTITIONS_SCHEMA}'
        AND c.relkind = 'r'
        AND c.relname ~ '^ai_events_counts_[0-9]{6}$'
        AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
    SQL
  end

  def foreign_keys(oid)
    select_values(<<~SQL)
      SELECT conname FROM pg_constraint WHERE conrelid = #{Integer(oid)} AND contype = 'f'
    SQL
  end
end
