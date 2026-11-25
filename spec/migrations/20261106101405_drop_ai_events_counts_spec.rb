# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe DropAiEventsCounts, feature_category: :value_stream_management do
  let(:connection) { ActiveRecord::Base.connection }
  let(:schema) { Gitlab::Database::DYNAMIC_PARTITIONS_SCHEMA }
  let(:attached_partition) { 'ai_events_counts_209901' }
  let(:detached_partition) { 'ai_events_counts_209902' }
  let(:detached_partitions) { table(:detached_partitions) }

  def table_exists?(name)
    connection.table_exists?(name)
  end

  before do
    connection.execute(<<~SQL)
      CREATE TABLE #{schema}.#{attached_partition}
        PARTITION OF ai_events_counts FOR VALUES FROM ('2099-01-01') TO ('2099-02-01');
      CREATE TABLE #{schema}.#{detached_partition}
        PARTITION OF ai_events_counts FOR VALUES FROM ('2099-02-01') TO ('2099-03-01');
      ALTER TABLE ai_events_counts DETACH PARTITION #{schema}.#{detached_partition};
      ALTER TABLE #{schema}.#{detached_partition}
        ADD CONSTRAINT fk_rails_99a3f4a8f1 FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
    SQL

    detached_partitions.create!(table_name: detached_partition, drop_after: 1.week.from_now)
  end

  it 'drops detached partitions before dropping the table', :aggregate_failures do
    expect { migrate! }
      .to change { table_exists?(:ai_events_counts) }.from(true).to(false)
      .and change { table_exists?("#{schema}.#{detached_partition}") }.from(true).to(false)
      .and change { table_exists?("#{schema}.#{attached_partition}") }.from(true).to(false)
      .and change { detached_partitions.where(table_name: detached_partition).count }.from(1).to(0)
  end

  context 'with a detached partition that has no foreign key' do
    let(:partition_without_foreign_key) { 'ai_events_counts_209903' }

    before do
      connection.execute(<<~SQL)
        CREATE TABLE #{schema}.#{partition_without_foreign_key}
          PARTITION OF ai_events_counts FOR VALUES FROM ('2099-03-01') TO ('2099-04-01');
        ALTER TABLE ai_events_counts DETACH PARTITION #{schema}.#{partition_without_foreign_key};
      SQL
    end

    it 'drops it too' do
      expect { migrate! }
        .to change { table_exists?("#{schema}.#{partition_without_foreign_key}") }.from(true).to(false)
    end
  end

  it 'keeps the detached_partitions rows of other tables' do
    detached_partitions.create!(table_name: 'web_hook_logs_202601', drop_after: 1.week.from_now)

    expect { migrate! }.not_to change { detached_partitions.where(table_name: 'web_hook_logs_202601').count }.from(1)
  end

  it 'recreates the table on rollback' do
    migrate!

    expect { schema_migrate_down! }.to change { table_exists?(:ai_events_counts) }.from(false).to(true)
  end
end
