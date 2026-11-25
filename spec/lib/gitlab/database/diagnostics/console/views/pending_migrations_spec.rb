# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Database::Diagnostics::Console::Views::PendingMigrations, feature_category: :database do
  let(:buffer) { StringIO.new }
  let(:printer) { Gitlab::Database::Diagnostics::Console::Printer.new(output: buffer) }

  let(:migrations) { [] }
  let(:migrations_capped) { false }
  let(:findings) { [] }
  let(:severity) { nil }
  let(:counts) { {} }

  let(:payload) do
    {
      pending_migrations: {
        migrations: migrations,
        migrations_capped: migrations_capped,
        findings: findings,
        severity: severity,
        counts: counts
      }
    }
  end

  subject(:view) { described_class.new(databases: { 'main' => payload }, printer: printer) }

  before do
    Rainbow.enabled = false
  end

  def rendered
    buffer.string.split("\n")
  end

  describe '.title' do
    it { expect(described_class.title).to eq('Pending migrations') }
  end

  describe '#run' do
    context 'with no pending migrations' do
      it 'reports the database as clean without a table', :aggregate_failures do
        expect(view.run).to eq({})

        expect(buffer.string).to eq("\n== Pending migrations ==\n\nmain ... OK\n\n")
      end
    end

    context 'with pending migrations' do
      let(:severity) { 'error' }
      let(:counts) { { 'error' => 1, 'warning' => 1 } }

      let(:findings) do
        [
          { severity: 'error', code: 'regular_migrations_pending', message: 'Schema is behind.' },
          { severity: 'warning', code: 'post_deployment_migrations_pending', message: 'Upgrade is not complete.' }
        ]
      end

      let(:migrations) do
        [
          { version: '20260101000001', name: 'AddColumn', type: 'regular' },
          { version: '20260101000002', name: 'BackfillColumn', type: 'post_deployment' }
        ]
      end

      it 'renders the findings and each migration', :aggregate_failures do
        expect(view.run).to eq({ 'error' => 1, 'warning' => 1 })

        expect(rendered).to include('main ... 1 error, 1 warning')
        expect(rendered.grep(/^   \[/)).to eq([
          '   [error]   Schema is behind.',
          '   [warning] Upgrade is not complete.'
        ])
        expect(rendered.last(4)).to match([
          /^   VERSION\s+NAME\s+TYPE$/,
          /^   -+\s+-+\s+-+$/,
          /^   20260101000001\s+AddColumn\s+regular$/,
          /^   20260101000002\s+BackfillColumn\s+post-deployment$/
        ])
      end

      context 'when the check cut the list' do
        let(:migrations_capped) { true }

        it 'says so under the table' do
          view.run

          expect(rendered.last)
            .to eq('   Only the first 50 migrations are listed. The findings count every migration.')
        end
      end
    end

    context 'when the collector could not read the database' do
      let(:payload) { { error: 'Failed to gather information for database: main' } }

      it 'counts an error and points at the logs for the cause', :aggregate_failures do
        expect(view.run).to eq({ 'error' => 1 })

        expect(rendered).to include(
          'main ... unavailable',
          '   Failed to gather information for database: main'
        )
        expect(buffer.string).to include('sent to the exception tracker')
      end
    end
  end
end
