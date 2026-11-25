# frozen_string_literal: true

require 'spec_helper'

require Rails.root.join(
  'db/click_house/post_migrate/main/20261112164636_bind_ai_usage_events_traversal_path_to_first_organization.rb'
)

RSpec.describe BindAiUsageEventsTraversalPathToFirstOrganization, :click_house, feature_category: :value_stream_management do
  let(:connection) { ::ClickHouse::Connection.new(:main) }
  let(:migration) { described_class.new(connection) }

  before do
    insert_event(user_id: 1, namespace_path: '9/42/', traversal_path: '0/', timestamp: '2026-04-15 10:00:00')
    insert_event(user_id: 2, namespace_path: '7/8/', traversal_path: '0/')
    insert_event(user_id: 3, namespace_path: '9/42/', traversal_path: '5/9/42/')
    insert_event(user_id: 4, namespace_path: '0/', traversal_path: '0/')
  end

  def insert_event(user_id:, namespace_path:, traversal_path:, timestamp: '2026-06-01 10:00:00')
    connection.execute(<<~SQL)
      INSERT INTO ai_usage_events (user_id, event, timestamp, namespace_path, traversal_path, extras)
      VALUES (#{user_id}, 2, toDateTime64('#{timestamp}', 6, 'UTC'), '#{namespace_path}',
        '#{traversal_path}', '{}')
    SQL
  end

  def paths_by_user
    connection
      .select('SELECT user_id, namespace_path, traversal_path FROM ai_usage_events ORDER BY user_id')
      .to_h { |row| [row['user_id'], [row['namespace_path'], row['traversal_path']]] }
  end

  def sentinel_count
    connection.select("SELECT count() AS c FROM ai_usage_events WHERE traversal_path = '0/'").first['c'].to_i
  end

  def downstream_occurrences
    connection.select('SELECT sum(occurrences) AS c FROM ai_usage_events_daily').first['c'].to_i
  end

  def run_and_settle
    migration.up
    ClickHouse::Client.execute('SYSTEM START MERGES ai_usage_events', click_house_admin_database)
    30.times do
      break if sentinel_count == 1

      sleep 0.1
    end
  end

  it 'binds sentinel rows to the default organization' do
    run_and_settle

    expect(paths_by_user).to eq(
      1 => ['9/42/', '1/9/42/'],
      2 => ['7/8/', '1/7/8/'],
      3 => ['9/42/', '5/9/42/'],
      4 => ['0/', '0/']
    )
  end

  it 'binds sentinel rows dated after the current month' do
    insert_event(user_id: 5, namespace_path: '7/8/', traversal_path: '0/',
      timestamp: 2.months.from_now.utc.strftime('%F %T'))

    run_and_settle

    expect(paths_by_user[5]).to eq(['7/8/', '1/7/8/'])
  end

  it 'binds sentinel rows at the start of a month' do
    insert_event(user_id: 5, namespace_path: '7/8/', traversal_path: '0/', timestamp: '2026-05-01 00:00:00')

    run_and_settle

    expect(paths_by_user[5]).to eq(['7/8/', '1/7/8/'])
  end

  it 'binds sentinel rows spread across several batches and skips the ranges after them' do
    stub_const("#{described_class}::BATCH_SIZE", 1)
    insert_event(user_id: 5, namespace_path: '7/7/', traversal_path: '7/7/')

    allow(migration).to receive(:execute).and_call_original
    expect(migration).to receive(:execute).with(/INSERT INTO/).exactly(3).times.and_call_original

    run_and_settle

    expect(paths_by_user).to eq(
      1 => ['9/42/', '1/9/42/'],
      2 => ['7/8/', '1/7/8/'],
      3 => ['9/42/', '5/9/42/'],
      4 => ['0/', '0/'],
      5 => ['7/7/', '7/7/']
    )
  end

  it 'does not count the repaired rows again downstream' do
    expect { run_and_settle }.not_to change { downstream_occurrences }.from(4)
  end

  it 'is idempotent' do
    run_and_settle
    described_class.new(connection).up

    expect(connection.select('SELECT count() AS c FROM ai_usage_events').first['c'].to_i).to eq(4)
  end
end
