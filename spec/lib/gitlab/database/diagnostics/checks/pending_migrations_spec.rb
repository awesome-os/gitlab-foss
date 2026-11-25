# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::Diagnostics::Checks::PendingMigrations, feature_category: :database do
  describe '#execute' do
    let(:root) { Dir.mktmpdir }
    let(:regular_path) { File.join(root, 'db', 'migrate') }
    let(:post_deployment_path) { File.join(root, 'db', 'post_migrate') }

    let(:applied_versions) { [] }
    let(:migration_context) do
      instance_double(
        ActiveRecord::MigrationContext,
        migrations_paths: [regular_path, post_deployment_path],
        get_all_versions: applied_versions
      )
    end

    let(:pool) do
      instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool, migration_context: migration_context)
    end

    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, pool: pool) }

    subject(:result) { described_class.new(connection).execute }

    before do
      FileUtils.mkdir_p([regular_path, post_deployment_path])
    end

    after do
      FileUtils.remove_entry(root)
    end

    def add_migration(path, version, name)
      FileUtils.touch(File.join(path, "#{version}_#{name}.rb"))
    end

    context 'when every migration has run' do
      let(:applied_versions) { [20260101000001, 20260101000002] }

      before do
        add_migration(regular_path, 20260101000001, 'add_column')
        add_migration(post_deployment_path, 20260101000002, 'backfill_column')
      end

      it 'reports nothing' do
        expect(result).to eq(migrations: [], migrations_capped: false, findings: [], severity: nil, counts: {})
      end
    end

    context 'when a version in the database has no file' do
      let(:applied_versions) { [20250101000001] }

      it 'does not report it' do
        expect(result[:migrations]).to be_empty
      end
    end

    context 'when a regular migration has not run' do
      let(:applied_versions) { [20260101000001] }

      before do
        add_migration(regular_path, 20260101000001, 'add_column')
        add_migration(regular_path, 20260101000003, 'add_other_column')
      end

      it 'lists it and reports an error', :aggregate_failures do
        expect(result[:migrations])
          .to contain_exactly({ version: '20260101000003', name: 'AddOtherColumn', type: 'regular' })
        expect(result[:severity]).to eq('error')
        expect(result[:counts]).to eq('error' => 1)
        expect(result[:findings]).to contain_exactly(a_hash_including(
          severity: 'error',
          code: 'regular_migrations_pending',
          message: a_string_matching(/\b1\b/)
        ))
      end
    end

    context 'when a post-deployment migration has not run' do
      before do
        add_migration(post_deployment_path, 20260101000002, 'backfill_column')
      end

      it 'lists it and reports a warning', :aggregate_failures do
        expect(result[:migrations])
          .to contain_exactly({ version: '20260101000002', name: 'BackfillColumn', type: 'post_deployment' })
        expect(result[:severity]).to eq('warning')
        expect(result[:counts]).to eq('warning' => 1)
        expect(result[:findings]).to contain_exactly(a_hash_including(
          severity: 'warning',
          code: 'post_deployment_migrations_pending',
          message: a_string_matching(/\b1\b/)
        ))
      end
    end

    context 'when migrations of both types have not run' do
      before do
        add_migration(post_deployment_path, 20260101000001, 'backfill_column')
        add_migration(regular_path, 20260101000004, 'add_other_column')
        add_migration(regular_path, 20260101000002, 'add_column')
        add_migration(post_deployment_path, 20260101000003, 'remove_column')
      end

      it 'lists regular migrations first, each type by version', :aggregate_failures do
        expect(result[:migrations].pluck(:version))
          .to eq(%w[20260101000002 20260101000004 20260101000001 20260101000003])
        expect(result[:severity]).to eq('error')
        expect(result[:counts]).to eq('error' => 1, 'warning' => 1)
        expect(result[:findings].pluck(:code))
          .to eq(%w[regular_migrations_pending post_deployment_migrations_pending])
        expect(result[:findings].pluck(:message)).to all(match(/\b2\b/))
      end
    end

    context 'when more migrations are pending than the limit' do
      before do
        stub_const("#{described_class}::MIGRATIONS_LIMIT", 2)

        add_migration(regular_path, 20260101000001, 'add_column')
        add_migration(post_deployment_path, 20260101000002, 'backfill_column')
        add_migration(post_deployment_path, 20260101000003, 'remove_column')
      end

      it 'cuts the list but counts every migration in the findings', :aggregate_failures do
        expect(result[:migrations].pluck(:version)).to eq(%w[20260101000001 20260101000002])
        expect(result[:migrations_capped]).to be(true)
        expect(result[:findings].last)
          .to include(code: 'post_deployment_migrations_pending', message: a_string_matching(/\b2\b/))
      end
    end

    context 'with a real connection' do
      let(:connection) { ApplicationRecord.connection }

      it 'reports a migration whose version is not in schema_migrations' do
        version = connection.select_value('SELECT max(version) FROM schema_migrations')
        connection.execute("DELETE FROM schema_migrations WHERE version = '#{version}'")

        expect(result[:migrations].pluck(:version)).to include(version)
      end
    end

    context 'when a file is not named like a migration' do
      before do
        add_migration(regular_path, 20260101000001, 'Not-A-Migration')
      end

      it 'reports an error that names the file instead of listing it', :aggregate_failures do
        expect(result[:migrations]).to be_empty
        expect(result[:severity]).to eq('error')
        expect(result[:findings]).to contain_exactly(a_hash_including(
          severity: 'error',
          code: 'migration_file_names_invalid',
          message: a_string_including('20260101000001_Not-A-Migration.rb')
        ))
      end
    end

    context 'when the process has no post-deployment migration path' do
      let(:migration_context) do
        instance_double(ActiveRecord::MigrationContext, migrations_paths: [regular_path], get_all_versions: [])
      end

      before do
        add_migration(post_deployment_path, 20260101000002, 'backfill_column')
      end

      it 'warns that post-deployment migrations were not checked', :aggregate_failures do
        expect(result[:migrations]).to be_empty
        expect(result[:severity]).to eq('warning')
        expect(result[:findings]).to contain_exactly(a_hash_including(
          severity: 'warning',
          code: 'post_deployment_migrations_not_checked'
        ))
      end
    end
  end
end
