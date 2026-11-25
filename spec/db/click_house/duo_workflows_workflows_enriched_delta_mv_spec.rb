# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'duo_workflows_workflows_enriched_delta_mv session credits', :click_house,
  feature_category: :value_stream_management do
  let(:connection) { ClickHouse::Connection.new(:main) }

  def refresh_view
    ClickHouse::Client.execute('SYSTEM REFRESH VIEW duo_workflows_workflows_enriched_delta_mv',
      click_house_admin_database)
    ClickHouse::Client.execute('SYSTEM WAIT VIEW duo_workflows_workflows_enriched_delta_mv',
      click_house_admin_database)
  end

  def enriched_credits
    connection.select(<<~SQL).to_h { |row| [row['id'], row['credits_used'].to_f] }
      SELECT id, argMax(credits_used, _version) AS credits_used
      FROM duo_workflows_workflows_enriched
      GROUP BY id
    SQL
  end

  def insert_credits(updated_at:)
    connection.execute(<<~SQL)
      INSERT INTO duo_workflow_session_enrichments (workflow_id, credits_used, model_used, updated_at, ingested_at)
      VALUES (1, 12.5, 'claude', #{updated_at}, now64(6))
    SQL
  end

  def insert_workflow(id, replicated_at)
    connection.execute(<<~SQL)
      INSERT INTO siphon_duo_workflows_workflows
        (id, traversal_path, created_at, updated_at, user_id, status, _siphon_replicated_at, _siphon_watermark)
      VALUES
        (#{id}, '1/', now64(6) - INTERVAL 4 HOUR, #{replicated_at}, 7, 3, #{replicated_at}, #{replicated_at})
    SQL
  end

  # Flow 2 changed just now and moves the window forward to now - 30 minutes.
  before do
    insert_workflow(2, 'now64(6)')
  end

  it 'picks up credits whose CustomersDot updated_at is older than the window' do
    # Flow 1 last changed in Siphon two hours ago, so only its credits row can bring it back.
    insert_workflow(1, 'now64(6) - INTERVAL 2 HOUR')
    refresh_view

    insert_credits(updated_at: 'now64(6) - INTERVAL 3 HOUR')
    refresh_view

    expect(enriched_credits).to eq(1 => 12.5, 2 => 0.0)
  end

  it 'outranks a row the mr_outcomes view versioned above the siphon row' do
    insert_workflow(1, 'now64(6) - INTERVAL 5 MINUTE')
    refresh_view

    # What duo_workflows_workflows_enriched_mr_outcomes_mv writes: the same row one microsecond up.
    connection.execute(<<~SQL)
      INSERT INTO duo_workflows_workflows_enriched (id, traversal_path, created_at, user_id, status, _version, _watermark)
      SELECT id, traversal_path, created_at, user_id, status, _version + toIntervalMicrosecond(1), _watermark
      FROM duo_workflows_workflows_enriched
      WHERE id = 1
    SQL

    # Inside the window, but older than the siphon row.
    insert_credits(updated_at: 'now64(6) - INTERVAL 10 MINUTE')
    refresh_view

    expect(enriched_credits).to eq(1 => 12.5, 2 => 0.0)
  end
end
