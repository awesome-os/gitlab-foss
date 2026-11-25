# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe SwapColumnsForCiSourcesPipelinesBigintConversion, migration: :gitlab_ci, feature_category: :database do
  let(:connection) { Ci::ApplicationRecord.connection }
  let(:table) { described_class::TABLE_NAME }
  let(:columns) { described_class::COLUMNS }
  let(:not_null_check) { 'check_5a76e457e6' }
  let(:tmp_not_null_check) { "#{not_null_check}_tmp" }

  # A fresh install already has bigint columns, so the state the conversion
  # leaves behind before the swap is rebuilt by hand.
  before do
    connection.execute(<<~SQL)
      ALTER TABLE #{table}
        ALTER COLUMN id TYPE integer,
        ALTER COLUMN project_id TYPE integer,
        ALTER COLUMN source_project_id TYPE integer,
        ADD COLUMN id_convert_to_bigint bigint NOT NULL DEFAULT 0,
        ADD COLUMN project_id_convert_to_bigint bigint,
        ADD COLUMN source_project_id_convert_to_bigint bigint,
        ADD CONSTRAINT #{tmp_not_null_check} CHECK (project_id_convert_to_bigint IS NOT NULL)
    SQL
  end

  after do
    connection.execute(<<~SQL)
      ALTER TABLE #{table}
        DROP COLUMN IF EXISTS id_convert_to_bigint,
        DROP COLUMN IF EXISTS project_id_convert_to_bigint,
        DROP COLUMN IF EXISTS source_project_id_convert_to_bigint,
        ALTER COLUMN id TYPE bigint,
        ALTER COLUMN project_id TYPE bigint,
        ALTER COLUMN source_project_id TYPE bigint
    SQL
  end

  it 'swaps the columns and keeps the NOT NULL check names on the columns they guard' do
    reversible_migration do |migration|
      migration.before -> {
        expect(column_types).to eq(
          'id' => 'integer', 'project_id' => 'integer', 'source_project_id' => 'integer',
          'id_convert_to_bigint' => 'bigint', 'project_id_convert_to_bigint' => 'bigint',
          'source_project_id_convert_to_bigint' => 'bigint'
        )
        expect(check_constraints).to eq(
          not_null_check => '(project_id IS NOT NULL)',
          tmp_not_null_check => '(project_id_convert_to_bigint IS NOT NULL)'
        )
      }

      migration.after -> {
        expect(column_types).to eq(
          'id' => 'bigint', 'project_id' => 'bigint', 'source_project_id' => 'bigint',
          'id_convert_to_bigint' => 'integer', 'project_id_convert_to_bigint' => 'integer',
          'source_project_id_convert_to_bigint' => 'integer'
        )
        expect(check_constraints).to eq(
          not_null_check => '(project_id IS NOT NULL)',
          tmp_not_null_check => '(project_id_convert_to_bigint IS NOT NULL)'
        )
        expect(primary_key_column).to eq('id')
      }
    end
  end

  private

  def column_types
    connection.columns(table)
      .select { |column| column.name.start_with?(*columns) }
      .to_h { |column| [column.name, column.sql_type] }
  end

  def check_constraints
    connection.select_rows(<<~SQL).to_h
      SELECT conname, pg_get_expr(conbin, conrelid)
      FROM pg_constraint
      WHERE conrelid = '#{table}'::regclass AND contype = 'c'
    SQL
  end

  def primary_key_column
    connection.primary_key(table)
  end
end
