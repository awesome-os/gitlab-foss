# frozen_string_literal: true

require 'spec_helper'

require Rails.root.join(
  'db/click_house/post_migrate/main/20261119132851_backfill_session_credits_on_duo_workflows_workflows_enriched.rb'
)

RSpec.describe BackfillSessionCreditsOnDuoWorkflowsWorkflowsEnriched, :click_house, feature_category: :value_stream_management do
  let(:connection) { ::ClickHouse::Connection.new(:main) }
  let(:migration) { described_class.new(connection) }

  let(:emitted_at) { "toDateTime64('2026-11-10 10:00:00', 6, 'UTC')" }

  def enriched_rows
    connection.select(<<~SQL).to_h { |row| [row['id'], row.except('id')] }
      SELECT
        id,
        argMax(credits_used, _version) AS credits,
        argMax(model_used, _version) AS model,
        argMax(status, _version) AS status,
        argMax(tuple(drop_reason), _version).1 AS drop_reason,
        toString(argMax(later_closed_merge_request_ids, _version)) AS later_closed,
        toString(max(_version)) AS version
      FROM duo_workflows_workflows_enriched
      GROUP BY id
      ORDER BY id
    SQL
  end

  def insert_enriched(values)
    connection.execute(<<~SQL)
      INSERT INTO duo_workflows_workflows_enriched
        (id, traversal_path, created_at, user_id, status, drop_reason, credits_used, model_used,
         later_closed_merge_request_ids, _version, _watermark)
      VALUES #{values}
    SQL
  end

  def insert_credits(values)
    connection.execute(<<~SQL)
      INSERT INTO duo_workflow_session_enrichments (workflow_id, credits_used, model_used, updated_at)
      VALUES #{values}
    SQL
  end

  # Flow 1 lost its credits and has an older version plus an mr_outcomes repair; flow 2 already
  # matches; flow 3 has credits but no enriched row; flow 4 has no credits; flow 5 sorts last;
  # flow 6 has the right credits but a stale model.
  before do
    # Each enriched row is its own insert, so its own part and granule, which the range example
    # needs; a background merge would fold them into one granule and one range.
    ClickHouse::Client.execute('SYSTEM STOP MERGES duo_workflows_workflows_enriched', click_house_admin_database)

    insert_enriched("(1, '1/', #{emitted_at}, 7, 1, NULL, 0, '', [], #{emitted_at} - INTERVAL 1 HOUR, #{emitted_at})")
    insert_enriched("(1, '1/', #{emitted_at}, 7, 4, 'job_failed', 0, '', [5], #{emitted_at}, #{emitted_at})")
    insert_enriched("(2, '1/', #{emitted_at}, 7, 3, NULL, 3, 'claude', [], #{emitted_at}, #{emitted_at})")
    insert_enriched("(4, '1/', #{emitted_at}, 7, 3, NULL, 0, '', [], #{emitted_at}, #{emitted_at})")
    insert_enriched("(5, '2/', #{emitted_at}, 7, 3, NULL, 0, '', [], #{emitted_at}, #{emitted_at})")
    insert_enriched("(6, '1/', #{emitted_at}, 7, 3, NULL, 4, 'claude', [], #{emitted_at}, #{emitted_at})")

    insert_credits(<<~SQL)
      (1, 5, 'gpt', toDateTime64('2026-11-10 09:00:00', 6, 'UTC')),
      (2, 3, 'claude', toDateTime64('2026-11-10 09:00:00', 6, 'UTC')),
      (3, 8, 'claude', toDateTime64('2026-11-10 09:00:00', 6, 'UTC')),
      (5, 2, 'claude', toDateTime64('2026-11-10 09:00:00', 6, 'UTC')),
      (6, 4, 'gpt', toDateTime64('2026-11-10 09:00:00', 6, 'UTC'))
    SQL
    # Its own insert, so the later CustomersDot version is not collapsed on insert.
    insert_credits("(1, 12.5, 'claude', toDateTime64('2026-11-10 11:00:00', 6, 'UTC'))")
  end

  after do
    ClickHouse::Client.execute('SYSTEM START MERGES duo_workflows_workflows_enriched', click_house_admin_database)
  end

  it 'writes the latest credits one microsecond above the newest version, keeping the rest' do
    migration.up

    expect(enriched_rows[1]).to eq(
      'credits' => 12.5,
      'model' => 'claude',
      'status' => 4,
      'drop_reason' => 'job_failed',
      'later_closed' => '[5]',
      'version' => '2026-11-10 10:00:00.000001'
    )
  end

  it 'writes the latest model when only the model differs' do
    migration.up

    expect(enriched_rows[6].slice('credits', 'model', 'version')).to eq(
      'credits' => 4, 'model' => 'gpt', 'version' => '2026-11-10 10:00:00.000001'
    )
  end

  it 'fixes rows in every range, not only the first' do
    stub_const("#{described_class}::BATCH_SIZE", 1)
    allow(migration).to receive(:execute).and_call_original
    expect(migration).to receive(:execute).with(/INSERT INTO/).at_least(3).times.and_call_original

    migration.up

    expect(enriched_rows.transform_values { |row| row['credits'] }).to include(1 => 12.5, 5 => 2)
  end

  it 'leaves matching rows and rows without credits untouched, and adds no rows' do
    migration.up

    expect(enriched_rows.except(1, 5, 6).transform_values { |row| [row['credits'], row['version']] }).to eq(
      2 => [3, '2026-11-10 10:00:00.000000'],
      4 => [0, '2026-11-10 10:00:00.000000']
    )
  end

  it 'is idempotent' do
    migration.up

    expect { migration.up }.not_to change { enriched_rows }
  end
end
