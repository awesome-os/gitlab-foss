# frozen_string_literal: true

require 'fast_spec_helper'
require 'rspec-parameterized'

require_relative '../../scripts/migration_schema_validator'

RSpec.describe MigrationSchemaValidator, feature_category: :database do
  subject(:validator) { described_class.new }

  describe '#validate!' do
    before do
      # CI sets CI_MERGE_REQUEST_LABELS from the MR under test; clear it so the
      # examples below do not inherit a real skip-validation label.
      stub_env('CI_MERGE_REQUEST_LABELS', '')

      allow(validator).to receive(:validate_schema_on_rollback!)
      allow(validator).to receive(:validate_schema_on_migrate!)
      allow(validator).to receive(:validate_schema_version_files!)
      allow(validator).to receive(:validate_ignore_columns!)

      allow(validator).to receive_messages(
        committed_migrations: committed_migrations,
        partition_manager_config_changes?: partition_config_changes
      )
    end

    context 'when there are no committed migrations and no partition config changes' do
      let(:committed_migrations) { [] }
      let(:partition_config_changes) { false }

      it 'returns early without running any validations', :aggregate_failures do
        expect(validator.validate!).to be_nil

        expect(validator).not_to have_received(:validate_ignore_columns!)
        expect(validator).not_to have_received(:validate_schema_on_rollback!)
        expect(validator).not_to have_received(:validate_schema_on_migrate!)
        expect(validator).not_to have_received(:validate_schema_version_files!)
      end
    end

    context 'when only partition manager config changes are present' do
      let(:committed_migrations) { [] }
      let(:partition_config_changes) { true }

      it 'runs the validations', :aggregate_failures do
        validator.validate!

        expect(validator).to have_received(:validate_ignore_columns!)
        expect(validator).to have_received(:validate_schema_on_rollback!)
        expect(validator).to have_received(:validate_schema_on_migrate!)
        expect(validator).to have_received(:validate_schema_version_files!)
      end
    end

    context 'when there are committed migrations' do
      let(:committed_migrations) { ['db/migrate/20240101000000_my_migration.rb'] }
      let(:partition_config_changes) { false }

      context 'and no skip-validation label is present' do
        it 'runs the ignore-columns and all schema validations', :aggregate_failures do
          validator.validate!

          expect(validator).to have_received(:validate_ignore_columns!)
          expect(validator).to have_received(:validate_schema_on_rollback!)
          expect(validator).to have_received(:validate_schema_on_migrate!)
          expect(validator).to have_received(:validate_schema_version_files!)
        end
      end

      context 'and a skip-validation label is present' do
        before do
          stub_env('CI_MERGE_REQUEST_LABELS', 'pipeline::skip-check-migrations')
        end

        it 'still runs ignore-columns but skips the schema validations', :aggregate_failures do
          expect(validator.validate!).to be_nil

          expect(validator).to have_received(:validate_ignore_columns!)
          expect(validator).not_to have_received(:validate_schema_on_rollback!)
          expect(validator).not_to have_received(:validate_schema_on_migrate!)
          expect(validator).not_to have_received(:validate_schema_version_files!)
        end
      end
    end
  end

  describe '#skip_validation_label' do
    using RSpec::Parameterized::TableSyntax

    subject(:skip_validation_label) { validator.send(:skip_validation_label) }

    where(:case_name, :labels, :expected) do
      'no labels'      | ''                                                   | nil
      'single-colon'   | 'some::label,pipeline:skip-check-migrations,another' | 'pipeline:skip-check-migrations'
      'double-colon'   | 'pipeline::skip-check-migrations'                    | 'pipeline::skip-check-migrations'
      'unrelated only' | 'type::feature,group::database'                      | nil
    end

    with_them do
      before do
        stub_env('CI_MERGE_REQUEST_LABELS', labels)
      end

      it 'returns the matched skip label or nil' do
        expect(skip_validation_label).to eq(expected)
      end
    end

    it 'memoizes the result' do
      stub_env('CI_MERGE_REQUEST_LABELS', 'pipeline::skip-check-migrations')

      expect(validator.send(:skip_validation_label)).to eq('pipeline::skip-check-migrations')

      stub_env('CI_MERGE_REQUEST_LABELS', '')

      expect(validator.send(:skip_validation_label)).to eq('pipeline::skip-check-migrations')
    end
  end

  describe '#find_migration_version' do
    subject(:find_migration_version) { validator.send(:find_migration_version, filename) }

    context 'when the filename has a valid 14-digit version prefix' do
      let(:filename) { 'db/migrate/20240101000000_foo.rb' }

      it { is_expected.to eq('20240101000000') }
    end

    context 'when the filename has no valid version prefix' do
      let(:filename) { 'db/migrate/foo.rb' }

      it 'terminates the execution' do
        expect { find_migration_version }.to raise_error(SystemExit)
      end
    end

    context 'when the version prefix has too few digits' do
      let(:filename) { 'db/migrate/2024010100_foo.rb' }

      it 'terminates the execution' do
        expect { find_migration_version }.to raise_error(SystemExit)
      end
    end
  end

  describe '#validate_ignore_columns!' do
    let(:migration_file) { 'db/migrate/20240101000000_remove_foo.rb' }
    let(:migration_content) do
      <<~RUBY
        class RemoveFoo < Gitlab::Database::Migration[2.2]
          def up
            remove_column :users, :foo
          end
        end
      RUBY
    end

    let(:model_content) { model_body }

    before do
      allow(validator).to receive(:committed_migrations).and_return([migration_file])

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(migration_file).and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(migration_file).and_return(migration_content)

      allow(validator).to receive(:model).with('users').and_return('User')
      allow(validator).to receive(:model_path).with('User').and_return('app/models/user.rb')
      allow(File).to receive(:exist?).with('app/models/user.rb').and_return(true)
      allow(File).to receive(:read).with('app/models/user.rb').and_return(model_content)
    end

    context 'when the model properly ignores the removed column' do
      let(:model_body) do
        <<~RUBY
          class User < ApplicationRecord
            ignore_column :foo, remove_with: '16.0', remove_after: '2024-01-01'
          end
        RUBY
      end

      it 'does not terminate the execution' do
        expect { validator.send(:validate_ignore_columns!) }.not_to raise_error
      end
    end

    context 'when the model ignores the removed column via the plural directive' do
      let(:model_body) do
        <<~RUBY
          class User < ApplicationRecord
            ignore_columns %i[foo bar], remove_with: '16.0', remove_after: '2024-01-01'
          end
        RUBY
      end

      it 'does not terminate the execution' do
        expect { validator.send(:validate_ignore_columns!) }.not_to raise_error
      end
    end

    context 'when the model does not ignore the removed column' do
      let(:model_body) do
        <<~RUBY
          class User < ApplicationRecord
          end
        RUBY
      end

      it 'terminates the execution' do
        expect { validator.send(:validate_ignore_columns!) }.to raise_error(SystemExit)
      end
    end

    context 'when the model ignores the removed column in a directive written in another form' do
      using RSpec::Parameterized::TableSyntax

      where(:case_name, :directive) do
        'symbols over several lines'    | "ignore_columns :bar_baz,\n    :foo,\n    remove_with: '16.0'"
        'word array over several lines' | "ignore_columns %i[\n      bar_baz\n      foo\n    ], remove_with: '16.0'"
        'symbol array'                  | "ignore_columns [:bar_baz, :foo], remove_with: '16.0'"
        'parenthesized call'            | "ignore_columns(:bar_baz, :foo, remove_with: '16.0')"
      end

      with_them do
        let(:model_body) do
          <<~RUBY
            class User < ApplicationRecord
              #{directive}
            end
          RUBY
        end

        it 'does not terminate the execution' do
          expect { validator.send(:validate_ignore_columns!) }.not_to raise_error
        end
      end
    end

    context 'when the removed column is i and the model only ignores other columns through %i[]' do
      let(:migration_content) do
        <<~RUBY
          class RemoveI < Gitlab::Database::Migration[2.2]
            def up
              remove_column :users, :i
            end
          end
        RUBY
      end

      let(:model_body) do
        <<~RUBY
          class User < ApplicationRecord
            ignore_columns %i[foo], remove_with: '16.0', remove_after: '2024-01-01'
          end
        RUBY
      end

      it 'terminates the execution' do
        expect { validator.send(:validate_ignore_columns!) }.to raise_error(SystemExit)
      end
    end

    context 'when the model ignores another column and mentions the removed column elsewhere' do
      let(:model_body) do
        <<~RUBY
          class User < ApplicationRecord
            ignore_column :bar, remove_with: '16.0', remove_after: '2024-01-01'

            # foo is still read here
            def label
              foo.to_s
            end
          end
        RUBY
      end

      it 'terminates the execution and names the model and column' do
        expect { validator.send(:validate_ignore_columns!) }
          .to raise_error(SystemExit).and output(/User: foo/).to_stdout
      end
    end

    context 'when the model ignores a column whose name ends with the removed column' do
      let(:model_body) do
        <<~RUBY
          class User < ApplicationRecord
            ignore_column :other_foo, remove_with: '16.0', remove_after: '2024-01-01'
          end
        RUBY
      end

      it 'terminates the execution' do
        expect { validator.send(:validate_ignore_columns!) }.to raise_error(SystemExit)
      end
    end

    context 'when the removed column is only named in a commented-out directive' do
      let(:model_body) do
        <<~RUBY
          class User < ApplicationRecord
            ignore_column :bar, remove_with: '16.0', remove_after: '2024-01-01'
            # ignore_column :foo, remove_with: '16.0', remove_after: '2024-01-01'
          end
        RUBY
      end

      it 'terminates the execution' do
        expect { validator.send(:validate_ignore_columns!) }.to raise_error(SystemExit)
      end
    end
  end

  describe '#diff_target' do
    subject(:diff_target) { validator.send(:diff_target) }

    before do
      allow(validator).to receive(:run)
    end

    context 'in a merge request pipeline' do
      before do
        stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', 'main')
      end

      it 'uses the target branch without resolving a merge base' do
        expect(diff_target).to eq('main')
        expect(validator).not_to have_received(:run)
      end
    end

    context 'when not in a merge request pipeline' do
      before do
        stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', nil)
        stub_env('TARGET', 'origin/master')
        stub_env('CI_COMMIT_SHA', nil)
        allow(validator).to receive(:run).with('git merge-base origin/master HEAD').and_return('abc123')
      end

      it { is_expected.to eq('abc123') }
    end
  end

  describe '#partition_manager_config_changes?' do
    subject(:partition_manager_config_changes?) { validator.send(:partition_manager_config_changes?) }

    before do
      allow(validator).to receive(:run).and_return(run_output)
    end

    context 'when the partition manager config file was changed' do
      let(:run_output) { 'config/initializers/postgres_partitioning.rb' }

      it { is_expected.to be(true) }
    end

    context 'when no partition manager config file was changed' do
      let(:run_output) { '' }

      it { is_expected.to be(false) }
    end
  end

  describe '#validate_schema_on_migrate!' do
    subject(:validate_schema_on_migrate!) { validator.send(:validate_schema_on_migrate!) }

    before do
      # run is called for db:migrate, db:schema:dump, and finally the git diff.
      # Only the git diff output determines pass/fail, so stub the migrate/dump
      # calls to succeed and control the final diff output per-context.
      #
      allow(validator).to receive(:run).with('scripts/db_tasks db:migrate').and_return('')
      allow(validator).to receive(:run).with('scripts/db_tasks db:schema:dump').and_return('')
      allow(validator).to receive(:run).with("git diff -- #{described_class::FILENAME}").and_return(diff_output)
    end

    context 'when the generated schema matches the committed one' do
      let(:diff_output) { '' }

      it 'does not terminate the execution' do
        expect { validate_schema_on_migrate! }.not_to raise_error
      end
    end

    context 'when the generated schema differs from the committed one' do
      let(:diff_output) { "@@ -1 +1 @@\n-old\n+new" }

      it 'terminates the execution' do
        expect { validate_schema_on_migrate! }.to raise_error(SystemExit)
      end
    end
  end

  describe '#validate_schema_on_rollback!' do
    subject(:validate_schema_on_rollback!) { validator.send(:validate_schema_on_rollback!) }

    let(:original_schema) do
      <<~SQL
        CREATE TABLE user_preferences (
            id bigint NOT NULL,
            use_work_items_view boolean DEFAULT false NOT NULL,
            text_editor_type smallint DEFAULT 2 NOT NULL,
            CONSTRAINT check_user_preferences_id CHECK ((id > 0))
        );

        CREATE INDEX index_user_preferences_on_id ON user_preferences USING btree (id);
      SQL
    end

    let(:rolled_back_schema) { original_schema }
    let(:rollback_diff) { 'diff --git a/db/structure.sql b/db/structure.sql' }

    before do
      allow(validator).to receive_messages(committed_migrations: ['db/post_migrate/20240101000000_remove_column.rb'],
        diff_target: 'master')
      allow(validator).to receive(:clear_schema_cache!)
      allow(validator).to receive(:run).with('scripts/db_tasks db:migrate:down VERSION=20240101000000')
      allow(validator).to receive(:run).with('scripts/db_tasks db:schema:dump')
      allow(validator).to receive(:run).with('git diff master -- db/structure.sql').and_return(rollback_diff)
      allow(Open3).to receive(:capture3).with('git', 'show', 'master:db/structure.sql')
        .and_return([original_schema, '', instance_double(Process::Status, success?: true)])
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with('db/structure.sql').and_return(rolled_back_schema)
    end

    context 'when the rollback produces no schema diff' do
      let(:rollback_diff) { '' }

      it 'does not read the original schema' do
        validate_schema_on_rollback!

        expect(Open3).not_to have_received(:capture3)
      end
    end

    context 'when the original schema cannot be read' do
      before do
        allow(Open3).to receive(:capture3).with('git', 'show', 'master:db/structure.sql')
          .and_return(['', 'fatal: bad revision', instance_double(Process::Status, success?: false)])
      end

      it 'rejects the rollback' do
        expect { validate_schema_on_rollback! }
          .to raise_error(SystemExit).and output(%r{could not read db/structure\.sql from master}).to_stdout
      end
    end

    context 'when the only difference is a column moved to the end' do
      let(:rolled_back_schema) do
        original_schema.sub(
          "    use_work_items_view boolean DEFAULT false NOT NULL,\n    text_editor_type smallint DEFAULT 2 NOT NULL,",
          "    text_editor_type smallint DEFAULT 2 NOT NULL,\n    use_work_items_view boolean DEFAULT false NOT NULL,")
      end

      it 'accepts the rollback' do
        expect { validate_schema_on_rollback! }.not_to raise_error
      end
    end

    context 'when a column is missing' do
      let(:rolled_back_schema) do
        original_schema.sub("    use_work_items_view boolean DEFAULT false NOT NULL,\n", '')
      end

      it 'rejects the rollback' do
        expect { validate_schema_on_rollback! }.to raise_error(SystemExit)
      end
    end

    context 'when a column definition changes' do
      let(:rolled_back_schema) { original_schema.sub('DEFAULT false NOT NULL', 'DEFAULT true NOT NULL') }

      it 'rejects the rollback' do
        expect { validate_schema_on_rollback! }.to raise_error(SystemExit)
      end
    end

    context 'when a constraint changes' do
      let(:rolled_back_schema) { original_schema.sub('id > 0', 'id > 1') }

      it 'rejects the rollback' do
        expect { validate_schema_on_rollback! }.to raise_error(SystemExit)
      end
    end

    context 'when table constraints are reordered' do
      let(:original_schema) do
        <<~SQL
          CREATE TABLE user_preferences (
              id bigint NOT NULL,
              use_work_items_view boolean DEFAULT false NOT NULL,
              CONSTRAINT check_id CHECK ((id > 0)),
              CONSTRAINT check_view CHECK ((id < 100))
          );
        SQL
      end

      let(:rolled_back_schema) do
        original_schema.sub(
          "    CONSTRAINT check_id CHECK ((id > 0)),\n    CONSTRAINT check_view CHECK ((id < 100))",
          "    CONSTRAINT check_view CHECK ((id < 100)),\n    CONSTRAINT check_id CHECK ((id > 0))")
      end

      it 'accepts the reordered constraints' do
        expect { validate_schema_on_rollback! }.not_to raise_error
      end
    end

    context 'when columns and table constraints are reordered together' do
      let(:original_schema) do
        <<~SQL
          CREATE TABLE user_preferences (
              id bigint NOT NULL,
              use_work_items_view boolean DEFAULT false NOT NULL,
              CONSTRAINT check_id CHECK ((id > 0)),
              CONSTRAINT check_view CHECK ((use_work_items_view IS NOT NULL))
          );
        SQL
      end

      let(:rolled_back_schema) do
        <<~SQL
          CREATE TABLE user_preferences (
              use_work_items_view boolean DEFAULT false NOT NULL,
              id bigint NOT NULL,
              CONSTRAINT check_view CHECK ((use_work_items_view IS NOT NULL)),
              CONSTRAINT check_id CHECK ((id > 0))
          );
        SQL
      end

      it 'accepts the rollback' do
        expect { validate_schema_on_rollback! }.not_to raise_error
      end
    end

    context 'when a reordered constraint has a different definition' do
      let(:original_schema) do
        <<~SQL
          CREATE TABLE user_preferences (
              id bigint NOT NULL,
              CONSTRAINT check_a CHECK ((id > 0)),
              CONSTRAINT check_b CHECK ((id < 100))
          );
        SQL
      end

      let(:rolled_back_schema) do
        original_schema.sub("    CONSTRAINT check_a CHECK ((id > 0)),\n    CONSTRAINT check_b CHECK ((id < 100))",
          "    CONSTRAINT check_b CHECK ((id < 100)),\n    CONSTRAINT check_a CHECK ((id > 1))")
      end

      it 'rejects the rollback' do
        expect { validate_schema_on_rollback! }.to raise_error(SystemExit)
      end
    end

    context 'when a table constraint is missing' do
      let(:rolled_back_schema) do
        original_schema.sub(",\n    CONSTRAINT check_user_preferences_id CHECK ((id > 0))", '')
      end

      it 'rejects the rollback' do
        expect { validate_schema_on_rollback! }.to raise_error(SystemExit)
      end
    end

    context 'when unnamed table constraints are reordered' do
      let(:original_schema) do
        <<~SQL
          CREATE TABLE user_preferences (
              id bigint NOT NULL,
              use_work_items_view boolean DEFAULT false NOT NULL,
              PRIMARY KEY (id),
              UNIQUE (use_work_items_view)
          );
        SQL
      end

      let(:rolled_back_schema) do
        original_schema.sub("    PRIMARY KEY (id),\n    UNIQUE (use_work_items_view)",
          "    UNIQUE (use_work_items_view),\n    PRIMARY KEY (id)")
      end

      it 'accepts the reordered constraints' do
        expect { validate_schema_on_rollback! }.not_to raise_error
      end
    end

    context 'when an index changes' do
      let(:rolled_back_schema) { original_schema.sub('USING btree', 'USING hash') }

      it 'rejects the rollback' do
        expect { validate_schema_on_rollback! }.to raise_error(SystemExit)
      end
    end

    context 'when a table has no constraints' do
      let(:original_schema) do
        <<~SQL
          CREATE TABLE user_preferences (
              id bigint NOT NULL,
              use_work_items_view boolean DEFAULT false NOT NULL,
              text_editor_type smallint DEFAULT 2 NOT NULL
          );
        SQL
      end

      let(:rolled_back_schema) do
        original_schema.sub(
          "    use_work_items_view boolean DEFAULT false NOT NULL,\n    text_editor_type smallint DEFAULT 2 NOT NULL",
          "    text_editor_type smallint DEFAULT 2 NOT NULL,\n    use_work_items_view boolean DEFAULT false NOT NULL")
      end

      it 'accepts the restored column at the end without a trailing comma', :aggregate_failures do
        expect(rolled_back_schema).to include("    use_work_items_view boolean DEFAULT false NOT NULL\n);")

        expect { validate_schema_on_rollback! }.not_to raise_error
      end
    end

    context 'when a partitioned table has reordered columns' do
      let(:original_schema) do
        <<~SQL
          CREATE TABLE events (
              id bigint NOT NULL,
              event_date date NOT NULL
          )
          PARTITION BY RANGE (event_date);
        SQL
      end

      let(:rolled_back_schema) do
        original_schema.sub("    id bigint NOT NULL,\n    event_date date NOT NULL",
          "    event_date date NOT NULL,\n    id bigint NOT NULL")
      end

      it 'accepts the rollback' do
        expect { validate_schema_on_rollback! }.not_to raise_error
      end
    end

    context 'when a column definition spans multiple lines' do
      let(:original_schema) do
        <<~SQL
          CREATE TABLE personal_access_tokens (
              id bigint NOT NULL,
              scopes character varying DEFAULT '--- []
          '::character varying NOT NULL,
              user_id bigint NOT NULL
          );
        SQL
      end

      let(:rolled_back_schema) do
        original_schema.sub("    id bigint NOT NULL,\n", '')
          .sub("    user_id bigint NOT NULL\n", "    user_id bigint NOT NULL,\n    id bigint NOT NULL\n")
      end

      it 'rejects the rollback rather than normalizing an unsupported definition' do
        expect { validate_schema_on_rollback! }.to raise_error(SystemExit)
      end
    end
  end
end
