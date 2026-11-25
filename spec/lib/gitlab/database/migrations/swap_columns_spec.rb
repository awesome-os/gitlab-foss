# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::Migrations::SwapColumns, feature_category: :database do
  describe '#execute' do
    let(:connection) { ApplicationRecord.connection }
    let(:sql) do
      <<~SQL
        CREATE TABLE #{table} (
          id integer NOT NULL,
          #{column1} integer DEFAULT 8 NOT NULL,
          #{column2} bigint DEFAULT 100 NOT NULL
        );
      SQL
    end

    let(:migration_context) do
      Gitlab::Database::Migration[2.1]
        .new('name', 'version')
        .extend(Gitlab::Database::MigrationHelpers::Swapping)
    end

    let(:table) { :_test_swap_columns_and_defaults }
    let(:column1) { :integer_column }
    let(:column2) { :bigint_column }
    # Only the options a context overrides are passed, so the defaults stay under test.
    let(:swap_options) { {} }

    subject(:execute_service) { perform_swap }

    # @note `subject` memoizes, so a rollback, which repeats the same swap, calls this instead.
    def perform_swap
      described_class.new(
        migration_context: migration_context,
        table: table,
        column1: column1,
        column2: column2,
        **swap_options
      ).execute
    end

    before do
      connection.execute(sql)
    end

    shared_examples_for 'swapping columns correctly' do
      specify do
        expect { execute_service }
          .to change { find_column_by(column1).sql_type }.from('integer').to('bigint')
          .and change { find_column_by(column2).sql_type }.from('bigint').to('integer')
      end
    end

    it_behaves_like 'swapping columns correctly'

    context 'when column names are 63 bytes' do
      let(:column1) { :int012345678901234567890123456789012345678901234567890123456789 }
      let(:column2) { :big012345678901234567890123456789012345678901234567890123456789 }

      it_behaves_like 'swapping columns correctly'
    end

    context 'with a column-specific trigger on a swapped column' do
      let(:trigger_name) { :_test_swap_columns_trigger }
      let(:function_name) { :_test_swap_columns_trigger_fn }

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            AFTER INSERT OR UPDATE OF #{column1}, id ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();
        SQL
      end

      it_behaves_like 'swapping columns correctly'

      it 'keeps the trigger bound to the original column names' do
        expect { execute_service }.not_to change { trigger_definition }

        expect(trigger_definition).to include("UPDATE OF #{column1}, id")
      end
    end

    context 'with a trigger whose WHEN clause references a swapped column' do
      let(:trigger_name) { :_test_swap_columns_when_trigger }
      let(:function_name) { :_test_swap_columns_when_fn }

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            AFTER UPDATE ON #{table}
            FOR EACH ROW
            WHEN (NEW.#{column1} IS DISTINCT FROM OLD.#{column1})
            EXECUTE FUNCTION #{function_name}();
        SQL
      end

      it_behaves_like 'swapping columns correctly'

      # The trigger has no `UPDATE OF` list, so it is only found through its `WHEN` clause.
      it 'keeps the WHEN clause bound to the original column names' do
        expect { execute_service }.not_to change { trigger_definition }

        expect(trigger_definition).to include("new.#{column1} IS DISTINCT FROM old.#{column1}")
      end
    end

    context 'with a column-specific trigger on an unrelated column' do
      let(:trigger_name) { :_test_swap_columns_unrelated_trigger }
      let(:function_name) { :_test_swap_columns_unrelated_fn }

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            AFTER UPDATE OF id ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();
        SQL
      end

      it 'is left untouched' do
        expect { execute_service }.not_to change { trigger_definition }
      end
    end

    context 'with a trigger that is not column-specific' do
      let(:trigger_name) { :_test_swap_columns_all_columns_trigger }
      let(:function_name) { :_test_swap_columns_all_columns_fn }

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NEW;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            BEFORE INSERT OR UPDATE ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();
        SQL
      end

      it 'is left untouched' do
        expect { execute_service }.not_to change { trigger_definition }
      end
    end

    context 'with a column-specific trigger on a partitioned table' do
      let(:table) { :_test_swap_columns_partitioned }
      let(:partition) { :_test_swap_columns_partition_1 }
      let(:trigger_name) { :_test_swap_columns_partitioned_trigger }
      let(:function_name) { :_test_swap_columns_partitioned_fn }
      let(:sql) do
        <<~SQL
          CREATE TABLE #{table} (
            id integer NOT NULL,
            #{column1} integer DEFAULT 8 NOT NULL,
            #{column2} bigint DEFAULT 100 NOT NULL
          ) PARTITION BY RANGE (id);

          CREATE TABLE #{partition} PARTITION OF #{table} FOR VALUES FROM (0) TO (100);
        SQL
      end

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            AFTER UPDATE OF #{column1} ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();
        SQL
      end

      it_behaves_like 'swapping columns correctly'

      # The clone is not among the definitions that get replayed: `CREATE OR REPLACE TRIGGER`
      # on the parent recurses into it.
      it 'keeps the trigger on the partition bound to the original column names' do
        expect { execute_service }.not_to change { trigger_definition(partition) }

        expect(trigger_definition(partition)).to include("UPDATE OF #{column1}")
      end
    end

    context 'with a trigger that uses a non-default firing mode' do
      let(:trigger_name) { :_test_swap_columns_mode_trigger }
      let(:function_name) { :_test_swap_columns_mode_fn }

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            AFTER UPDATE OF #{column1} ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();

          ALTER TABLE #{table} #{mode_statement} TRIGGER #{trigger_name};
        SQL
      end

      context 'when the trigger is set to ENABLE ALWAYS' do
        let(:mode_statement) { 'ENABLE ALWAYS' }

        it_behaves_like 'swapping columns correctly'

        it 'keeps the firing mode' do
          expect { execute_service }.not_to change { firing_mode(table) }.from('A')
        end
      end

      context 'when the trigger is set to ENABLE REPLICA' do
        let(:mode_statement) { 'ENABLE REPLICA' }

        it 'keeps the firing mode' do
          expect { execute_service }.not_to change { firing_mode(table) }.from('R')
        end
      end

      context 'when the trigger is disabled' do
        let(:mode_statement) { 'DISABLE' }

        it 'keeps the firing mode' do
          expect { execute_service }.not_to change { firing_mode(table) }.from('D')
        end
      end
    end

    context 'when only a sub-partition clone uses a non-default firing mode' do
      let(:table) { :_test_swap_columns_partitioned_mode }
      let(:sub_partition) { :_test_swap_columns_partition_mode_sub }
      let(:leaf_partition) { :_test_swap_columns_partition_mode_leaf }
      let(:trigger_name) { :_test_swap_columns_partitioned_mode_trigger }
      let(:function_name) { :_test_swap_columns_partitioned_mode_fn }
      let(:sql) do
        <<~SQL
          CREATE TABLE #{table} (
            id integer NOT NULL,
            #{column1} integer DEFAULT 8 NOT NULL,
            #{column2} bigint DEFAULT 100 NOT NULL
          ) PARTITION BY RANGE (id);

          CREATE TABLE #{sub_partition} PARTITION OF #{table}
            FOR VALUES FROM (0) TO (100) PARTITION BY RANGE (id);

          CREATE TABLE #{leaf_partition} PARTITION OF #{sub_partition} FOR VALUES FROM (0) TO (50);
        SQL
      end

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            AFTER UPDATE OF #{column1} ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();

          ALTER TABLE #{leaf_partition} ENABLE REPLICA TRIGGER #{trigger_name};
        SQL
      end

      it_behaves_like 'swapping columns correctly'

      # The leaf clone's parent is the clone on the sub-partition, not the trigger being
      # swapped, so only a recursive walk reaches it.
      it 'keeps the firing mode of the leaf clone' do
        expect { execute_service }.not_to change { firing_mode(leaf_partition) }.from('R')
      end

      it 'leaves the other relations in the default firing mode' do
        execute_service

        expect(firing_mode(table)).to eq('O')
        expect(firing_mode(sub_partition)).to eq('O')
      end
    end

    context 'when a partitioned table and one of its clones use different firing modes' do
      # Named so the clone sorts before the parent, which is the restore order that would let
      # the parent's recursion overwrite the clone.
      let(:table) { :_test_swap_columns_modes_parent }
      let(:partition) { :_test_swap_columns_modes_child }
      let(:trigger_name) { :_test_swap_columns_mixed_modes_trigger }
      let(:function_name) { :_test_swap_columns_mixed_modes_fn }
      let(:sql) do
        <<~SQL
          CREATE TABLE #{table} (
            id integer NOT NULL,
            #{column1} integer DEFAULT 8 NOT NULL,
            #{column2} bigint DEFAULT 100 NOT NULL
          ) PARTITION BY RANGE (id);

          CREATE TABLE #{partition} PARTITION OF #{table} FOR VALUES FROM (0) TO (100);
        SQL
      end

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE TRIGGER #{trigger_name}
            AFTER UPDATE OF #{column1} ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();

          ALTER TABLE ONLY #{table} ENABLE ALWAYS TRIGGER #{trigger_name};
          ALTER TABLE ONLY #{partition} ENABLE REPLICA TRIGGER #{trigger_name};
        SQL
      end

      it 'keeps both firing modes' do
        execute_service

        expect(firing_mode(table)).to eq('A')
        expect(firing_mode(partition)).to eq('R')
      end
    end

    context 'when called outside a transaction' do
      before do
        allow(migration_context).to receive(:transaction_open?).and_return(false)
      end

      it 'raises without renaming any columns' do
        expect { execute_service }
          .to raise_error(/outside a transaction/)
          .and not_change { find_column_by(column1).sql_type }
      end
    end

    context 'with a constraint trigger on a swapped column' do
      let(:trigger_name) { :_test_swap_columns_constraint_trigger }
      let(:function_name) { :_test_swap_columns_constraint_fn }

      before do
        connection.execute(<<~SQL)
          CREATE FUNCTION #{function_name}() RETURNS trigger AS $$
          BEGIN
            RETURN NULL;
          END $$ LANGUAGE plpgsql;

          CREATE CONSTRAINT TRIGGER #{trigger_name}
            AFTER UPDATE OF #{column1} ON #{table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();
        SQL
      end

      it 'raises without renaming any columns' do
        expect { execute_service }
          .to raise_error(/constraint trigger\(s\) #{trigger_name}/)
          .and not_change { find_column_by(column1).sql_type }

        expect(find_column_by(column2).sql_type).to eq('bigint')
      end
    end

    context 'with check constraints on the swapped columns' do
      let(:table) { :_test_swap_columns_check_constraints }
      let(:column1) { :widget_id }
      let(:column2) { :widget_id_convert_to_bigint }
      let(:sql) do
        <<~SQL
          CREATE TABLE #{table} (
            id integer NOT NULL,
            other_id integer,
            #{column1} integer,
            #{column2} bigint
          );
        SQL
      end

      def add_check(name, expression, validate: true)
        connection.execute(<<~SQL)
          ALTER TABLE #{table}
            ADD CONSTRAINT #{name} CHECK (#{expression}) #{'NOT VALID' unless validate}
        SQL
      end

      # @note Mirrors what the cleanup migration does once the swap has shipped.
      def drop_retiring_column
        connection.execute("ALTER TABLE #{table} DROP COLUMN #{column2}")
      end

      def check_constraint_expression(name, on_table = table)
        connection.select_value(<<~SQL)
          SELECT pg_get_expr(conbin, conrelid) FROM pg_constraint
          WHERE conrelid = '#{on_table}'::regclass AND conname = '#{name}'
        SQL
      end

      def check_constraint_names
        connection.select_values(<<~SQL)
          SELECT conname FROM pg_constraint
          WHERE conrelid = '#{table}'::regclass AND contype = 'c'
          ORDER BY conname
        SQL
      end

      def check_constraint_names_by_expression
        connection.select_rows(<<~SQL).group_by(&:last).transform_values { |rows| rows.map(&:first) }
          SELECT conname, pg_get_expr(conbin, conrelid) FROM pg_constraint
          WHERE conrelid = '#{table}'::regclass AND contype = 'c'
          ORDER BY conname
        SQL
      end

      def column_types_of(constraint_name)
        connection.select_values(<<~SQL)
          SELECT format_type(a.atttypid, a.atttypmod)
          FROM pg_constraint c
          JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
          WHERE c.conrelid = '#{table}'::regclass AND c.conname = '#{constraint_name}'
        SQL
      end

      context 'when every constraint on the retiring column has a validated counterpart' do
        before do
          add_check(:check_int, "#{column1} > 0")
          add_check(:check_bigint, "#{column2} > 0")
        end

        it_behaves_like 'swapping columns correctly'

        # Exchanging the names keeps each name on the column it was written for, so the name
        # means the same thing before and after the swap.
        it 'keeps each constraint name on the column it guards' do
          expect { execute_service }
            .to not_change { check_constraint_expression(:check_int) }.from("(#{column1} > 0)")
            .and not_change { check_constraint_expression(:check_bigint) }
            .from("(#{column2} > 0)")
        end

        it 'leaves the canonical name on the column that cleanup keeps' do
          execute_service
          drop_retiring_column

          expect(check_constraint_names).to eq(%w[check_int])
        end
      end

      context 'when the counterpart is only NOT VALID' do
        before do
          add_check(:check_int, "#{column1} > 0")
          add_check(:check_bigint, "#{column2} > 0", validate: false)
        end

        it 'raises naming the counterpart, without renaming any columns' do
          expect { execute_service }
            .to raise_error(/check_bigint would outlive the swap but is NOT VALID/)
            .and not_change { find_column_by(column1).sql_type }
        end

        # `check_bigint` sorts first, but the override should name the constraint cleanup drops.
        it 'suggests excluding the constraint on the retiring column' do
          expect { execute_service }
            .to raise_error(/skip_check_constraint_verification: %w\[check_int\]/)
        end
      end

      # The reverse of the previous case: pairing with something stronger loses no guarantee.
      context 'when the retiring constraint is NOT VALID and its counterpart is validated' do
        before do
          add_check(:check_int, "#{column1} > 0", validate: false)
          add_check(:check_bigint, "#{column2} > 0")
        end

        it_behaves_like 'swapping columns correctly'
      end

      context 'when a constraint on the retiring column has no counterpart' do
        before do
          add_check(:check_int, "#{column1} > 0")
        end

        it 'raises without renaming any columns' do
          expect { execute_service }
            .to raise_error(/Add `.*#{column2}.*` as NOT VALID/)
            .and not_change { find_column_by(column1).sql_type }

          expect(find_column_by(column2).sql_type).to eq('bigint')
        end

        it 'names the constraint and suggests the override' do
          expect { execute_service }.to raise_error(
            /check_int: \(widget_id > 0\).*skip_check_constraint_verification: %w\[check_int\]/m
          )
        end

        context 'when the constraint is excluded from the verification' do
          let(:swap_options) { { skip_check_constraint_verification: %w[check_int] } }

          it_behaves_like 'swapping columns correctly'

          # Alone in its group, so there is nothing to move the name onto.
          it 'leaves the constraint name alone' do
            expect { execute_service }
              .to change { check_constraint_expression(:check_int) }
              .from("(#{column1} > 0)").to("(#{column2} > 0)")
          end

          # Excluding turns off the verification for the expression, not the renaming.
          context 'when a NOT VALID counterpart exists' do
            before do
              add_check(:check_bigint, "#{column2} > 0", validate: false)
            end

            it 'still moves the name onto the counterpart' do
              expect { execute_service }
                .to not_change { check_constraint_expression(:check_int) }.from("(#{column1} > 0)")
            end
          end
        end

        # Ignoring an entry that matches nothing would hide the constraint it was meant to
        # cover, which is the opposite of what the option is for.
        context 'when an excluded name is not a constraint on the retiring column' do
          let(:swap_options) { { skip_check_constraint_verification: %w[check_typo] } }

          it 'raises without renaming any columns' do
            expect { execute_service }
              .to raise_error(
                /check_typo .* did not match a check constraint on #{table}/
              )
              .and not_change { find_column_by(column1).sql_type }
          end
        end

        # A rollback repeats the same swap, so the constraint the author excluded is on the
        # other column the second time round.
        context 'when an excluded name belongs to the surviving column' do
          let(:swap_options) { { skip_check_constraint_verification: %w[check_int check_bigint] } }

          before do
            add_check(:check_bigint, "#{column2} > 0")
          end

          it_behaves_like 'swapping columns correctly'
        end
      end

      # One surviving constraint is enough, however many duplicates guard the retiring column:
      # the expression is still enforced after cleanup.
      context 'when two identical constraints on the retiring column share one counterpart' do
        before do
          add_check(:check_int_a, "#{column1} > 0")
          add_check(:check_int_b, "#{column1} > 0")
          add_check(:check_bigint, "#{column2} > 0")
        end

        it_behaves_like 'swapping columns correctly'
      end

      context 'when a constraint references both swapped columns' do
        before do
          add_check(:check_both, "#{column1} > 0 AND #{column2} > 0")
        end

        it 'raises without renaming any columns' do
          expect { execute_service }
            .to raise_error(/check constraint\(s\) check_both reference both columns/)
            .and not_change { find_column_by(column1).sql_type }
        end

        context 'when the constraint is excluded from the verification' do
          let(:swap_options) { { skip_check_constraint_verification: %w[check_both] } }

          it_behaves_like 'swapping columns correctly'
        end
      end

      # `widget_id` would be in two pairs: with its counterpart, and with the column swapped.
      context 'when the first column is swapped with something other than its counterpart' do
        let(:column2) { :other_bigint_id }
        let(:sql) do
          <<~SQL
            CREATE TABLE #{table} (
              id integer NOT NULL,
              #{column1} integer,
              widget_id_convert_to_bigint bigint,
              #{column2} bigint
            );
          SQL
        end

        it 'raises without renaming any columns' do
          expect { execute_service }
            .to raise_error(/widget_id belong.* to more than one conversion pair/)
            .and not_change { find_column_by(column1).sql_type }
        end
      end

      # `swap_columns` is not limited to bigint conversions, so the pairing cannot rely on the
      # second column being named after the first.
      context 'when the columns do not follow the bigint conversion naming' do
        let(:column1) { :old_widget_id }
        let(:column2) { :new_widget_id }

        before do
          add_check(:check_old, "#{column1} > 0")
          add_check(:check_new, "#{column2} > 0")
        end

        it_behaves_like 'swapping columns correctly'
      end

      context 'when a constraint references only unrelated columns' do
        before do
          add_check(:check_other, 'other_id > 0')
        end

        it_behaves_like 'swapping columns correctly'
      end

      # The unrelated column is read under one name on both sides, so it drops out of the
      # comparison and only the swapped column decides the pairing.
      context 'when a constraint also references a column that is not being swapped' do
        before do
          add_check(:check_int, "#{column1} > 0 AND other_id > 0")
          add_check(:check_bigint, "#{column2} > 0 AND other_id > 0")
        end

        it_behaves_like 'swapping columns correctly'

        it 'keeps each constraint name on the column it guards' do
          expect { execute_service }
            .to not_change { check_constraint_expression(:check_int) }
            .from("((#{column1} > 0) AND (other_id > 0))")
        end

        context 'when the counterpart covers a different unrelated column' do
          before do
            connection.execute("ALTER TABLE #{table} DROP CONSTRAINT check_bigint")
            add_check(:check_bigint, "#{column2} > 0 AND id > 0")
          end

          it 'raises without renaming any columns' do
            expect { execute_service }
              .to raise_error(/Add `.*#{column2}.*` as NOT VALID/)
              .and not_change { find_column_by(column1).sql_type }
          end
        end
      end

      context 'when a constraint spans two columns that are both being converted' do
        let(:sql) do
          <<~SQL
            CREATE TABLE #{table} (
              id integer NOT NULL,
              #{column1} integer,
              #{column2} bigint,
              group_id integer,
              group_id_convert_to_bigint bigint
            );
          SQL
        end

        before do
          add_check(:check_int, "num_nonnulls(#{column1}, group_id) = 1")
          add_check(:check_bigint, "num_nonnulls(#{column2}, group_id_convert_to_bigint) = 1")
        end

        # Only `widget_id` is swapped here, so the counterpart still reads
        # `group_id_convert_to_bigint`. The two are equivalent only once both pairs are read
        # under the same name.
        it_behaves_like 'swapping columns correctly'

        context 'when the counterpart covers a different column' do
          before do
            connection.execute("ALTER TABLE #{table} DROP CONSTRAINT check_bigint")
            add_check(:check_bigint, "num_nonnulls(#{column2}, id) = 1")
          end

          it 'raises without renaming any columns' do
            expect { execute_service }
              .to raise_error(/Add `.*#{column2}.*` as NOT VALID/)
              .and not_change { find_column_by(column1).sql_type }
          end
        end
      end

      # A migration's `down` calls `swap_columns` again with the same arguments, so each case
      # has to survive being applied twice.
      context 'when the migration is rolled back' do
        shared_examples_for 'restoring the columns' do
          it 'puts both columns back' do
            perform_swap

            expect { perform_swap }
              .to change { find_column_by(column1).sql_type }.from('bigint').to('integer')
              .and change { find_column_by(column2).sql_type }.from('integer').to('bigint')
          end
        end

        context 'with paired constraints' do
          before do
            add_check(:check_int, "#{column1} > 0")
            add_check(:check_bigint, "#{column2} > 0")
          end

          it_behaves_like 'restoring the columns'

          it 'restores the constraint names' do
            perform_swap

            expect { perform_swap }
              .to not_change { check_constraint_expression(:check_int) }.from("(#{column1} > 0)")
          end
        end

        context 'with a constraint excluded from the verification' do
          let(:swap_options) { { skip_check_constraint_verification: %w[check_int] } }

          before do
            add_check(:check_int, "#{column1} > 0")
          end

          it_behaves_like 'restoring the columns'
        end

        # PostgreSQL renders an `IN` list with the column's own type, so these two never match
        # and both names have to be excluded.
        context 'with a pair whose rendering depends on the column type' do
          before do
            add_check(:check_int, "#{column1} IN (1, 2)")
            add_check(:check_bigint, "#{column2} IN (1, 2)")
          end

          context 'when both names are excluded' do
            let(:swap_options) { { skip_check_constraint_verification: %w[check_int check_bigint] } }

            it_behaves_like 'restoring the columns'
          end

          # Only the integer-side constraint needs excluding. Its counterpart reads the column
          # that keeps the data, so it outlives the swap in either direction.
          context 'when only the integer side is excluded' do
            let(:swap_options) { { skip_check_constraint_verification: %w[check_int] } }

            it_behaves_like 'restoring the columns'
          end
        end
      end

      # A constraint naming two converting columns is swapped once per column, so the name has
      # to move only on the swap that changes which constraint outlives the conversion.
      context 'when two converting columns share one constraint' do
        let(:table) { :_test_swap_columns_shared_check }
        let(:sql) do
          <<~SQL
            CREATE TABLE #{table} (
              id integer NOT NULL,
              widget_id integer,
              widget_id_convert_to_bigint bigint,
              gadget_id integer,
              gadget_id_convert_to_bigint bigint
            );
          SQL
        end

        let(:original) { 'num_nonnulls(widget_id, gadget_id) = 1' }

        def swap(column)
          described_class.new(
            migration_context: migration_context, table: table,
            column1: column, column2: :"#{column}_convert_to_bigint", **swap_options
          ).execute
        end

        # @note Mirrors what the cleanup migration leaves behind.
        def drop_conversion_columns
          connection.execute(<<~SQL)
            ALTER TABLE #{table}
              DROP COLUMN widget_id_convert_to_bigint,
              DROP COLUMN gadget_id_convert_to_bigint
          SQL
        end

        context 'with one counterpart naming both bigint columns' do
          before do
            add_check(:check_canonical, original)
            add_check(:check_tmp, 'num_nonnulls(widget_id_convert_to_bigint, gadget_id_convert_to_bigint) = 1')
          end

          it 'leaves the canonical name on the constraint that cleanup keeps' do
            swap(:widget_id)
            swap(:gadget_id)
            drop_conversion_columns

            expect(check_constraint_names).to eq(%w[check_canonical])
            expect(check_constraint_expression(:check_canonical)).to eq("(#{original})")
          end

          it 'restores the original names when both swaps are rolled back' do
            swap(:widget_id)
            swap(:gadget_id)
            swap(:gadget_id)
            swap(:widget_id)

            expect(check_constraint_expression(:check_canonical)).to eq("(#{original})")
          end
        end

        # Each batch adds the counterpart for the columns it swaps, the way duplicate indexes
        # are created per batch.
        context 'with one counterpart added per batch' do
          before do
            add_check(:check_canonical, original)
            add_check(:check_batch_one, 'num_nonnulls(widget_id_convert_to_bigint, gadget_id) = 1')
          end

          it 'moves the canonical name along the chain and keeps it after cleanup' do
            swap(:widget_id)

            expect(check_constraint_expression(:check_canonical)).to eq("(#{original})")

            add_check(:check_batch_two, 'num_nonnulls(widget_id, gadget_id_convert_to_bigint) = 1')
            swap(:gadget_id)
            drop_conversion_columns

            expect(check_constraint_names).to eq(%w[check_canonical])
            expect(check_constraint_expression(:check_canonical)).to eq("(#{original})")
          end
        end

        context 'when the second batch forgets its counterpart' do
          before do
            add_check(:check_canonical, original)
            add_check(:check_batch_one, 'num_nonnulls(widget_id_convert_to_bigint, gadget_id) = 1')
          end

          it 'swaps the first column, then raises with the expression to add' do
            swap(:widget_id)

            expect { swap(:gadget_id) }.to raise_error(
              /Add `\(num_nonnulls\(widget_id, gadget_id_convert_to_bigint\) = 1\)` as NOT VALID/
            )
          end
        end

        context 'when no counterpart names the bigint columns' do
          before do
            add_check(:check_canonical, original)
          end

          it 'raises on the first swap with the expression to add' do
            expect { swap(:widget_id) }.to raise_error(
              /Add `\(num_nonnulls\(widget_id_convert_to_bigint, gadget_id_convert_to_bigint\) = 1\)`/
            )
          end
        end

        # Every earlier defect in the renaming surfaced on a path nobody had traced, such as a
        # rollback of one batch only. So every sequence of swaps up to four long is walked for
        # both ways of writing the counterparts, checking the holder of the name after each.
        context 'on every sequence of swaps and rollbacks' do
          let(:counterpart_sets) do
            {
              'one counterpart on both bigint columns' => {
                check_tmp: 'num_nonnulls(widget_id_convert_to_bigint, gadget_id_convert_to_bigint) = 1'
              },
              'one counterpart per batch' => {
                check_batch_one: 'num_nonnulls(widget_id_convert_to_bigint, gadget_id) = 1',
                check_batch_two: 'num_nonnulls(widget_id, gadget_id_convert_to_bigint) = 1',
                check_tmp: 'num_nonnulls(widget_id_convert_to_bigint, gadget_id_convert_to_bigint) = 1'
              }
            }
          end

          let(:columns) { %i[widget_id gadget_id] }
          let(:paths) { (1..4).flat_map { |length| columns.repeated_permutation(length).to_a } }

          # With one counterpart on both bigint columns, the first swap leaves no constraint
          # reading only live names, so the canonical name has to be on the constraint that
          # reads only bigint columns instead.
          it 'keeps the canonical name on the constraint that outlives the conversion' do
            counterpart_sets.each do |label, counterparts|
              paths.each do |path|
                connection.transaction(requires_new: true) do
                  add_check(:check_canonical, original)
                  counterparts.each { |name, expression| add_check(name, expression) }

                  path.each_with_index do |column, step|
                    swap(column)

                    live = check_constraint_names_by_expression["(#{original})"]
                    where = "#{label}, after #{path.first(step + 1).join(' > ')}"

                    if live
                      expect(live).to eq(%w[check_canonical]), "#{where}: #{live.join(', ')} " \
                        "reads the live columns but check_canonical is on another constraint"
                    else
                      expect(column_types_of(:check_canonical)).to all(eq('bigint')), "#{where}: " \
                        "check_canonical is not on the constraint that reads only bigint columns"
                    end
                  end

                  raise ActiveRecord::Rollback
                end
              end
            end
          end
        end
      end

      context 'when the counterpart is inherited by a partition' do
        let(:table) { :_test_swap_columns_check_partitioned }
        let(:partition) { :_test_swap_columns_check_partition_1 }
        let(:sql) do
          <<~SQL
            CREATE TABLE #{table} (
              id integer NOT NULL,
              #{column1} integer,
              #{column2} bigint
            ) PARTITION BY RANGE (id);

            CREATE TABLE #{partition} PARTITION OF #{table} FOR VALUES FROM (0) TO (100);
          SQL
        end

        before do
          add_check(:check_int, "#{column1} > 0")
          add_check(:check_bigint, "#{column2} > 0")
        end

        it_behaves_like 'swapping columns correctly'

        # Declared on the partition, so it has no row on the parent and pairing cannot see it.
        context 'when a partition declares its own constraint' do
          before do
            connection.execute(
              "ALTER TABLE #{partition} ADD CONSTRAINT check_local CHECK (#{column1} IS NOT NULL)"
            )
          end

          it 'raises without renaming any columns' do
            expect { execute_service }
              .to raise_error(/#{partition}\.check_local .* declared on a partition/)
              .and not_change { find_column_by(column1).sql_type }
          end
        end

        context 'when a partition declares a constraint on an unrelated column' do
          before do
            connection.execute(
              "ALTER TABLE #{partition} ADD CONSTRAINT check_local CHECK (id > 0)"
            )
          end

          it_behaves_like 'swapping columns correctly'
        end

        # A partition's copy of the constraint cannot be renamed on its own, so the exchange
        # has to reach it through the parent.
        it 'exchanges the names on the partition too' do
          execute_service

          expect(check_constraint_expression(:check_int, partition)).to eq("(#{column1} > 0)")
          expect(check_constraint_expression(:check_bigint, partition)).to eq("(#{column2} > 0)")
        end
      end
    end

    private

    def find_column_by(name)
      connection.columns(table).find { |c| c.name == name.to_s }
    end

    def trigger_definition(on_table = table)
      connection.select_value(<<~SQL)
        SELECT pg_get_triggerdef(oid)
        FROM pg_trigger
        WHERE tgrelid = '#{on_table}'::regclass AND tgname = '#{trigger_name}'
      SQL
    end

    def firing_mode(on_table)
      connection.select_value(<<~SQL)
        SELECT tgenabled
        FROM pg_trigger
        WHERE tgrelid = '#{on_table}'::regclass AND tgname = '#{trigger_name}'
      SQL
    end
  end

  # The check constraint verification reads PostgreSQL's own rendering of a constraint and
  # compares the two sides of a swap. These examples pin the behaviour it relies on, so an
  # upgrade that changes either one is caught here rather than in a conversion migration.
  describe 'PostgreSQL behaviour the check constraint verification relies on' do
    let(:connection) { ApplicationRecord.connection }
    let(:table) { :_test_swap_columns_pg_behaviour }

    before do
      connection.execute(<<~SQL)
        CREATE TABLE #{table} (
          other_id integer,
          widget_id integer,
          widget_id_convert_to_bigint bigint
        );
      SQL
    end

    it 'drops a check constraint along with its column, without reporting it' do
      connection.execute("ALTER TABLE #{table} ADD CONSTRAINT check_a CHECK (widget_id > 0)")
      connection.execute(
        "ALTER TABLE #{table} ADD CONSTRAINT check_b CHECK (num_nonnulls(widget_id, other_id) = 1)"
      )

      expect { connection.execute("ALTER TABLE #{table} DROP COLUMN widget_id") }
        .to change { check_constraint_names }.from(%w[check_a check_b]).to([])
    end

    # Without this, a constraint that the author did pair up would be reported as unpaired.
    describe 'rendering a constraint under the name the swap gives its column' do
      where(:shape, :expression) do
        [
          ['IS NOT NULL', '%{column} IS NOT NULL'],
          ['comparison to a literal', '%{column} > 0'],
          ['range', '%{column} BETWEEN 1 AND 100'],
          ['comparison to another column', '%{column} <> other_id'],
          ['multiple columns', 'num_nonnulls(%{column}, other_id) = 1']
        ]
      end

      with_them do
        it 'renders both sides of the swap identically' do
          connection.execute(<<~SQL)
            ALTER TABLE #{table} ADD CONSTRAINT check_int
              CHECK (#{format(expression, column: 'widget_id')});
            ALTER TABLE #{table} ADD CONSTRAINT check_bigint
              CHECK (#{format(expression, column: 'widget_id_convert_to_bigint')});
          SQL

          before_swap = check_constraint_expression('check_int')
          expect(before_swap).to include('widget_id')

          swap_the_columns

          expect(check_constraint_expression('check_bigint')).to eq(before_swap)
        end
      end
    end

    # The known exception, and the reason `swap_columns` takes an override. A literal is
    # rendered with the column's own type, so the two sides never match for these shapes.
    describe 'rendering that depends on the column type' do
      where(:shape, :expression) do
        [
          ['IN list', '%{column} IN (1, 2, 3)'],
          ['explicit cast', '%{column}::bigint > 0']
        ]
      end

      with_them do
        it 'renders the two sides of the swap differently' do
          connection.execute(<<~SQL)
            ALTER TABLE #{table} ADD CONSTRAINT check_int
              CHECK (#{format(expression, column: 'widget_id')});
            ALTER TABLE #{table} ADD CONSTRAINT check_bigint
              CHECK (#{format(expression, column: 'widget_id_convert_to_bigint')});
          SQL

          before_swap = check_constraint_expression('check_int')

          swap_the_columns

          expect(check_constraint_expression('check_bigint')).not_to eq(before_swap)
        end
      end
    end

    private

    def swap_the_columns
      connection.execute(<<~SQL)
        ALTER TABLE #{table} RENAME COLUMN widget_id TO temp_name_for_renaming;
        ALTER TABLE #{table} RENAME COLUMN widget_id_convert_to_bigint TO widget_id;
        ALTER TABLE #{table} RENAME COLUMN temp_name_for_renaming TO widget_id_convert_to_bigint;
      SQL
    end

    def check_constraint_names
      connection.select_values(<<~SQL)
        SELECT conname FROM pg_constraint
        WHERE conrelid = '#{table}'::regclass AND contype = 'c'
        ORDER BY conname
      SQL
    end

    def check_constraint_expression(name)
      connection.select_value(<<~SQL)
        SELECT pg_get_expr(conbin, conrelid) FROM pg_constraint
        WHERE conrelid = '#{table}'::regclass AND conname = '#{name}'
      SQL
    end
  end
end
