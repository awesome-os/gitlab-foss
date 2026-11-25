# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Encryption::DbKeyBaseRotation::TableReencryptor, feature_category: :cell do
  using RSpec::Parameterized::TableSyntax

  include DbKeyBaseHelpers

  let_it_be(:project) { create(:project) }

  # Read before any example stubs the keys
  let!(:old_key) { Settings.db_key_base_keys.last }
  let(:new_key) { SecureRandom.hex(64) }

  let(:url_column) { Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn.new(WebHook, :url) }
  let(:token_column) { Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn.new(WebHook, :token) }
  let(:table) { Gitlab::Encryption::DbKeyBaseRotation::Table.new('web_hooks', WebHook, [url_column, token_column]) }

  def create_hook(key, url: 'https://example.com/hook')
    create_with_key(key) { create(:project_hook, project: project, url: url, token: 'hook-token') }
  end

  def run(reencryptor, relation = table.scope)
    reencryptor.reencrypt(relation).to_h
  end

  def readable_with_new_key_only?(hook)
    stub_db_key_base_keys(new_key)
    reloaded = WebHook.find(hook.id)

    %i[url token].all? { |attribute| reloaded.attr_encrypted_encrypted_with(attribute) == :current }
  end

  describe '#reencrypt' do
    context 'with rows on the old key and on the current key' do
      let!(:old_hook) { create_hook(old_key) }
      let!(:new_hook) { create_hook(new_key) }

      before do
        stub_db_key_base_keys(old_key, new_key)
      end

      it 're-encrypts the old rows and skips the current ones', :aggregate_failures do
        expect(run(described_class.new(table))).to eq(reencrypted: 1, skipped: 1, conflict: 0, error: 0)
        expect(readable_with_new_key_only?(old_hook)).to be(true)
        expect(WebHook.find(old_hook.id).url).to eq('https://example.com/hook')
      end

      it 'does not change the rows otherwise' do
        expect { run(described_class.new(table)) }.not_to change { old_hook.reload.updated_at }
      end

      it 'does not instantiate the model' do
        expect(WebHook).not_to receive(:instantiate)

        run(described_class.new(table))
      end

      it 'writes without a savepoint outside a transaction' do
        allow(WebHook.connection).to receive(:transaction_open?).and_return(false)

        expect(WebHook).not_to receive(:transaction)

        expect(run(described_class.new(table))).to eq(reencrypted: 1, skipped: 1, conflict: 0, error: 0)
      end

      it 'only counts the rows in a dry run', :aggregate_failures do
        encrypted_url = WebHook.where(id: old_hook.id).pick(:encrypted_url)

        expect(run(described_class.new(table, dry_run: true))).to eq(reencrypted: 1, skipped: 1, conflict: 0, error: 0)
        expect(WebHook.where(id: old_hook.id).pick(:encrypted_url)).to eq(encrypted_url)
      end
    end

    context 'with a batch of the rows' do
      let!(:hooks) { Array.new(2) { create_hook(old_key) } }

      before do
        stub_db_key_base_keys(old_key, new_key)
      end

      it 'only re-encrypts the rows of the relation', :aggregate_failures do
        expect(run(described_class.new(table), WebHook.where(id: hooks.first.id)))
          .to eq(reencrypted: 1, skipped: 0, conflict: 0, error: 0)
        expect(WebHook.find(hooks.second.id).attr_encrypted_encrypted_with(:url)).to eq(:previous)
      end

      it 'reads a relation of another model on the same table, like a background operation sub-batch' do
        sub_batch_model = Class.new(ApplicationRecord) { self.table_name = 'web_hooks' }

        expect(run(described_class.new(table), sub_batch_model.all))
          .to eq(reencrypted: 2, skipped: 0, conflict: 0, error: 0)
      end
    end

    context 'when the row changes after it is read' do
      let!(:hook) { create_hook(old_key) }

      before do
        stub_db_key_base_keys(old_key, new_key)
      end

      it 'leaves the concurrent edit and counts a conflict', :aggregate_failures do
        allow(url_column).to receive(:reencrypt).and_wrap_original do |method, *args|
          method.call(*args).tap { WebHook.find(hook.id).update!(url: 'https://example.com/edited') }
        end

        expect(run(described_class.new(table))).to eq(reencrypted: 0, skipped: 0, conflict: 1, error: 0)
        expect(WebHook.find(hook.id).url).to eq('https://example.com/edited')
      end
    end

    context 'when a column does not decrypt' do
      let!(:hook) { create_hook(old_key) }

      before do
        stub_db_key_base_keys(old_key, new_key)
        allow(token_column).to receive(:reencrypt).and_raise(OpenSSL::Cipher::CipherError)
      end

      it 'reports it and still re-encrypts the other columns', :aggregate_failures do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(
            an_instance_of(described_class::ColumnError)
              .and(having_attributes(message: "web_hooks couldn't re-encrypt encrypted_token (OpenSSL::Cipher::CipherError)")),
            table_name: 'web_hooks', record_id: hook.id, columns: token_column.columns
          )

        expect(run(described_class.new(table))).to eq(reencrypted: 0, skipped: 0, conflict: 0, error: 1)
        expect(WebHook.find(hook.id).attr_encrypted_encrypted_with(:url)).to eq(:current)
      end

      it 'only reports the first failure of a column' do
        create_hook(old_key)

        expect(Gitlab::ErrorTracking).to receive(:track_exception).once

        expect(run(described_class.new(table))[:error]).to eq(2)
      end
    end

    context 'when a column does not deserialize' do
      let(:url_variables_column) do
        Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn.new(WebHook, :url_variables)
      end

      let(:table) { Gitlab::Encryption::DbKeyBaseRotation::Table.new('web_hooks', WebHook, [url_variables_column]) }
      let!(:hook) { create_hook(old_key) }

      before do
        options = WebHook.attr_encrypted_encrypted_attributes[:url_variables]
        iv = SecureRandom.random_bytes(12)
        malformed = create_with_key(old_key) do
          key = Gitlab::Encryption::KeyProvider[options[:key]].encryption_key.secret
          WebHook.attr_encrypted_encrypt(:url_variables, '{"secret-value',
            options.merge(key: key, iv: iv, marshal: false))
        end
        WebHook.where(id: hook.id).update_all(encrypted_url_variables: malformed, encrypted_url_variables_iv: iv)
        stub_db_key_base_keys(old_key, new_key)
      end

      it 'reports it without the decrypted value' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(
            an_instance_of(described_class::ColumnError)
              .and(having_attributes(message: "web_hooks couldn't re-encrypt encrypted_url_variables (JSON::ParserError)")),
            table_name: 'web_hooks', record_id: hook.id, columns: url_variables_column.columns
          )

        expect(run(described_class.new(table))).to eq(reencrypted: 0, skipped: 0, conflict: 0, error: 1)
      end
    end

    context 'when the write violates a unique index' do
      let(:table) do
        Gitlab::Encryption::DbKeyBaseRotation::Table.new('ci_triggers', Ci::Trigger,
          [Gitlab::Encryption::DbKeyBaseRotation::TokenColumn.new(:token)])
      end

      let!(:duplicate) { create_with_key(old_key) { create(:ci_trigger, project: project) } }
      let!(:other) { create_with_key(old_key) { create(:ci_trigger, project: project) } }

      before do
        stub_db_key_base_keys(old_key, new_key)
        # Another row already holds the value the duplicate is re-encrypted to
        create(:ci_trigger, project: project).tap do |trigger|
          Ci::Trigger.where(id: trigger.id)
            .update_all(token_encrypted: Authn::TokenField::EncryptionHelper.encrypt_token(duplicate.token))
        end
      end

      it 'reports it and still re-encrypts the next rows', :aggregate_failures do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(
            an_instance_of(ActiveRecord::RecordNotUnique)
              .and(having_attributes(message: 'ci_triggers rejected the re-encrypted values (PG::UniqueViolation)')),
            table_name: 'ci_triggers', record_id: duplicate.id, columns: %w[token_encrypted]
          )

        expect(run(described_class.new(table))).to eq(reencrypted: 1, skipped: 1, conflict: 0, error: 1)
        expect(Ci::Trigger.where(id: other.id).pick(:token_encrypted))
          .to eq(Authn::TokenField::EncryptionHelper.encrypt_token(other.token))
      end
    end

    # Other rejections are hard to cause with valid data, so the write is stubbed to raise.
    context 'when the database rejects the write' do
      let!(:hook) { create_hook(old_key) }

      def raise_on_write(error, cause: nil)
        allow(table).to receive(:scope).and_wrap_original do |method|
          method.call.extending(Module.new do
            define_method(:update_all) { |*| cause ? raise(error, cause: cause) : raise(error) }
          end)
        end
      end

      before do
        stub_db_key_base_keys(old_key, new_key)
      end

      where(:error_class, :cause_class, :database_message, :reported_class) do
        ActiveRecord::RecordNotUnique | nil | 'Key (encrypted_token)=(ciphertext) already exists' |
          'ActiveRecord::RecordNotUnique'
        ActiveRecord::ValueTooLong | nil | 'value too long for type character varying(255): ciphertext' |
          'ActiveRecord::ValueTooLong'
        ActiveRecord::StatementInvalid | PG::CheckViolation | 'Failing row contains (1, ciphertext)' |
          'PG::CheckViolation'
      end

      with_them do
        it 'reports it without the values and counts an error', :aggregate_failures do
          raise_on_write(error_class.new(database_message), cause: cause_class&.new(database_message))

          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(
              an_instance_of(error_class)
                .and(having_attributes(message: "web_hooks rejected the re-encrypted values (#{reported_class})")),
              table_name: 'web_hooks', record_id: hook.id,
              columns: match_array(url_column.columns + token_column.columns)
            )

          expect(run(described_class.new(table))).to eq(reencrypted: 0, skipped: 0, conflict: 0, error: 1)
          expect(WebHook.find(hook.id).attr_encrypted_encrypted_with(:url)).to eq(:previous)
        end
      end

      context 'when the write violates a NOT NULL or foreign key constraint' do
        where(:error_class, :cause_class) do
          ActiveRecord::NotNullViolation | PG::NotNullViolation
          ActiveRecord::InvalidForeignKey | PG::ForeignKeyViolation
        end

        with_them do
          it 'raises it without the values' do
            raise_on_write(error_class.new('Failing row contains (1, ciphertext)'),
              cause: cause_class.new('Failing row contains (1, ciphertext)'))

            expect { run(described_class.new(table)) }.to raise_error(error_class) { |error|
              expect(error).to have_attributes(message: "web_hooks rejected the re-encrypted values (#{cause_class})",
                cause: nil)
            }
          end
        end
      end

      context 'when the write times out' do
        it 'raises it as it is' do
          raise_on_write(ActiveRecord::QueryCanceled.new('canceling statement due to statement timeout'))

          expect { run(described_class.new(table)) }
            .to raise_error(ActiveRecord::QueryCanceled, 'canceling statement due to statement timeout')
        end
      end
    end

    context 'with job tokens' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

      let(:table) do
        Gitlab::Encryption::DbKeyBaseRotation::Table.new('p_ci_builds', CommitStatus,
          [Gitlab::Encryption::DbKeyBaseRotation::TokenColumn.new(:token)])
      end

      it 'only re-encrypts the tokens of unfinished builds', :aggregate_failures do
        running = create_with_key(old_key) { create(:ci_build, :running, pipeline: pipeline) }
        finished = create_with_key(old_key) { create(:ci_build, :success, pipeline: pipeline) }
        stub_db_key_base_keys(old_key, new_key)
        finished_token = Ci::Build.where(id: finished.id).pick(:token_encrypted)

        expect(run(described_class.new(table))).to eq(reencrypted: 1, skipped: 0, conflict: 0, error: 0)
        expect(Ci::Build.where(id: running.id).pick(:token_encrypted))
          .to eq(Authn::TokenField::EncryptionHelper.encrypt_token(running.token))
        expect(Ci::Build.where(id: finished.id).pick(:token_encrypted)).to eq(finished_token)
      end
    end
  end
end
