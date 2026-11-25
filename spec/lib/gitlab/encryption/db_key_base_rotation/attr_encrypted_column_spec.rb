# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn, feature_category: :cell do
  using RSpec::Parameterized::TableSyntax

  include DbKeyBaseHelpers

  # Created with the real key so that other encrypted values stay readable
  let_it_be(:project) { create(:project) }

  # Read before any example stubs the keys
  let!(:old_key) { Settings.db_key_base_keys.last }
  let(:new_key) { SecureRandom.hex(64) }

  def stored_values(record, column)
    column.columns.zip(record.class.unscoped.where(id: record.id).pick(*column.columns)).to_h
  end

  def write(record, values)
    record.class.unscoped.where(id: record.id).update_all(values)
  end

  describe '.supported?' do
    it 'accepts attributes encrypted with a db_key_base key' do
      expect(described_class.supported?(Ci::Variable, :value)).to be(true)
    end

    it 'rejects attributes encrypted with another key' do
      expect(described_class.supported?(User, :otp_secret)).to be(false)
    end

    context 'with a condition' do
      def model_encrypting_url(condition)
        Class.new(ApplicationRecord) do
          self.table_name = 'web_hooks'

          include Gitlab::EncryptedAttribute

          attr_encrypted :url, mode: :per_attribute_iv, key: :db_key_base_32, algorithm: 'aes-256-gcm', **condition
        end
      end

      where(:option, :value, :supported) do
        :if     | true            | true
        :unless | false           | true
        :if     | false           | false
        :if     | :url_encrypted? | false
        :unless | true            | false
        :unless | :url_encrypted? | false
      end

      with_them do
        it 'accepts only attributes that are always encrypted' do
          expect(described_class.supported?(model_encrypting_url(option => value), :url)).to be(supported)
        end
      end

      it 'rejects a proc condition' do
        expect(described_class.supported?(model_encrypting_url(if: -> { true }), :url)).to be(false)
      end
    end
  end

  describe '#columns' do
    it 'lists the ciphertext and IV columns' do
      expect(described_class.new(ProjectHook, :url).columns).to eq(%w[encrypted_url encrypted_url_iv])
    end

    it 'adds the salt column when the mode uses one' do
      expect(described_class.new(Ci::Variable, :value).columns)
        .to eq(%w[encrypted_value encrypted_value_iv encrypted_value_salt])
    end
  end

  describe '#reencrypt' do
    shared_examples 're-encrypts with the current key' do |model_name, attribute|
      subject(:column) { described_class.new(model_name.constantize, attribute) }

      context 'when an older key encrypted the value' do
        let!(:record) { create_with_key(old_key) { create_record } }

        before do
          stub_db_key_base_keys(old_key, new_key)
        end

        it 'returns new values that only the current key needs', :aggregate_failures do
          stored = stored_values(record, column)
          new_values = column.reencrypt(stored)

          expect(new_values.keys).to match_array(column.columns)
          expect(new_values[column.columns.second]).not_to eq(stored[column.columns.second])

          write(record, new_values)
          stub_db_key_base_keys(new_key)
          reloaded = record.class.find(record.id)

          expect(reloaded.public_send(attribute)).to eq(value)
          expect(reloaded.attr_encrypted_encrypted_with(attribute)).to eq(:current)
        end
      end

      context 'when the current key encrypted the value' do
        it 'returns nil' do
          stub_db_key_base_keys(old_key, new_key)

          expect(column.reencrypt(stored_values(create_record, column))).to be_nil
        end
      end
    end

    context 'with an aes-256-gcm attribute' do
      let(:value) { 'https://example.com/hook' }

      def create_record
        create(:project_hook, project: project, url: value)
      end

      it_behaves_like 're-encrypts with the current key', 'ProjectHook', :url
    end

    context 'with an aes-256-gcm attribute marshaled as JSON' do
      let(:value) { { 'name' => 'secret' } }

      def create_record
        create(:project_hook, project: project, url: 'https://example.com/{name}', url_variables: value)
      end

      it_behaves_like 're-encrypts with the current key', 'ProjectHook', :url_variables
    end

    context 'with a bytea aes-256-gcm attribute' do
      let(:value) { 'chat-token' }

      def create_record
        create(:chat_name, token: value)
      end

      it_behaves_like 're-encrypts with the current key', 'ChatName', :token
    end

    context 'with an aes-256-cbc attribute with a salt' do
      let(:value) { 'variable value' }

      def create_record
        create(:ci_variable, project: project, value: value)
      end

      it_behaves_like 're-encrypts with the current key', 'Ci::Variable', :value
    end

    context 'with an aes-256-cbc attribute with a salt, marshaled with Marshal' do
      let(:value) { { user: 'user', password: 'password' } }

      def create_record
        create(:remote_mirror, project: project, url: 'https://user:password@example.com/repo.git')
      end

      it_behaves_like 're-encrypts with the current key', 'RemoteMirror', :credentials
    end

    context 'with a marshaled value' do
      subject(:column) { described_class.new(RemoteMirror, :credentials) }

      it 're-encrypts the stored bytes without dumping them again', :aggregate_failures do
        record = create_with_key(old_key) do
          create(:remote_mirror, project: project, url: 'https://user:password@example.com/repo.git')
        end
        stored = stored_values(record, column)
        stub_db_key_base_keys(old_key, new_key)
        options = RemoteMirror.attr_encrypted_encrypted_attributes[:credentials]

        expect(options[:marshaler]).not_to receive(options[:dump_method])

        new_values = column.reencrypt(stored)
        plaintext = ->(values, key) do
          RemoteMirror.attr_encrypted_decrypt(:credentials, values['encrypted_credentials'],
            iv: Base64.decode64(values['encrypted_credentials_iv']),
            salt: Base64.decode64(values['encrypted_credentials_salt'].delete_prefix('_')),
            key: key, marshal: false)
        end

        expect(plaintext.call(new_values, new_key).b).to eq(plaintext.call(stored, old_key).b)
      end
    end

    context 'when an older key also seems to decrypt the new value' do
      it 'encrypts it again with a new IV', :aggregate_failures do
        column = described_class.new(Ci::Variable, :value)
        record = create_with_key(old_key) { create(:ci_variable, project: project, value: 'variable value') }
        stored = stored_values(record, column)
        stub_db_key_base_keys(old_key, new_key)
        # The first call finds the key of the stored value, the second checks the first new value
        calls = 0
        allow(Ci::Variable).to receive(:attr_encrypted_decrypt_with_keys).and_wrap_original do |method, *args|
          calls += 1
          calls == 2 ? ['garbage', :previous, nil] : method.call(*args)
        end

        expect(Ci::Variable).to receive(:attr_encrypted_encrypt).twice.and_call_original

        write(record, column.reencrypt(stored))
        stub_db_key_base_keys(new_key)

        expect(Ci::Variable.find(record.id).value).to eq('variable value')
      end
    end

    context 'when the stored IV is empty' do
      it 'decrypts the value without an IV, as attr_encrypted does', :aggregate_failures do
        column = described_class.new(ApplicationSetting, :asset_proxy_secret_key)
        options = ApplicationSetting.attr_encrypted_encrypted_attributes[:asset_proxy_secret_key]
        old_secret = create_with_key(old_key) { Gitlab::Encryption::KeyProvider[options[:key]].encryption_key.secret }
        stored = {
          'encrypted_asset_proxy_secret_key' => ApplicationSetting.attr_encrypted_encrypt(
            :asset_proxy_secret_key, 'secret', options.merge(key: old_secret)),
          'encrypted_asset_proxy_secret_key_iv' => ''
        }
        stub_db_key_base_keys(old_key, new_key)

        new_values = column.reencrypt(stored)

        expect(new_values['encrypted_asset_proxy_secret_key_iv']).to be_present
        expect(column.reencrypt(new_values)).to be_nil
      end
    end

    context 'when the stored salt is empty' do
      # Without a salt, the key is used as it is, so it must be 32 bytes
      let(:model) do
        Class.new(Ci::ApplicationRecord) do
          self.table_name = 'ci_variables'

          include Gitlab::EncryptedAttribute

          attr_encrypted :value, mode: :per_attribute_iv_and_salt, insecure_mode: true, key: :db_key_base_32,
            algorithm: 'aes-256-cbc'
        end
      end

      it 'decrypts the value without a salt, as attr_encrypted does', :aggregate_failures do
        column = described_class.new(model, :value)
        options = model.attr_encrypted_encrypted_attributes[:value]
        old_secret = create_with_key(old_key) { Gitlab::Encryption::KeyProvider[options[:key]].encryption_key.secret }
        iv = SecureRandom.random_bytes(16)
        stored = {
          'encrypted_value' => model.attr_encrypted_encrypt(:value, 'secret', options.merge(key: old_secret, iv: iv)),
          'encrypted_value_iv' => Base64.strict_encode64(iv),
          'encrypted_value_salt' => ''
        }
        stub_db_key_base_keys(old_key, new_key)

        new_values = column.reencrypt(stored)

        expect(new_values['encrypted_value_salt']).to start_with('_')
        expect(column.reencrypt(new_values)).to be_nil
      end
    end

    context 'when the salt is stored without encoding' do
      let(:model) do
        Class.new(Ci::ApplicationRecord) do
          self.table_name = 'ci_variables'

          include Gitlab::EncryptedAttribute

          attr_encrypted :value, mode: :per_attribute_iv_and_salt, insecure_mode: true, key: :db_key_base,
            algorithm: 'aes-256-cbc', encode_salt: false
        end
      end

      it 'stores the new salt without encoding too', :aggregate_failures do
        column = described_class.new(model, :value)
        options = model.attr_encrypted_encrypted_attributes[:value]
        old_secret = create_with_key(old_key) { Gitlab::Encryption::KeyProvider[options[:key]].encryption_key.secret }
        iv = SecureRandom.random_bytes(16)
        salt = SecureRandom.random_bytes
        stored = {
          'encrypted_value' => model.attr_encrypted_encrypt(:value, 'secret',
            options.merge(key: old_secret, iv: iv, salt: salt)),
          'encrypted_value_iv' => Base64.strict_encode64(iv),
          'encrypted_value_salt' => salt
        }
        stub_db_key_base_keys(old_key, new_key)

        new_values = column.reencrypt(stored)
        decrypted = model.attr_encrypted_decrypt(:value, new_values['encrypted_value'],
          options.merge(key: Gitlab::Encryption::KeyProvider[options[:key]].encryption_key.secret,
            iv: Base64.decode64(new_values['encrypted_value_iv']), salt: new_values['encrypted_value_salt']))

        expect(decrypted).to eq('secret')
        expect(column.reencrypt(new_values)).to be_nil
      end
    end

    context 'when the value is empty' do
      it 'returns nil' do
        column = described_class.new(ProjectHook, :url)

        expect(column.reencrypt('encrypted_url' => nil, 'encrypted_url_iv' => nil)).to be_nil
      end
    end

    context 'when no key decrypts the value' do
      it 'raises' do
        column = described_class.new(ProjectHook, :url)
        stored = stored_values(create_with_key(SecureRandom.hex(64)) do
          create(:project_hook, project: project, url: 'https://example.com/hook')
        end, column)
        stub_db_key_base_keys(old_key, new_key)

        expect { column.reencrypt(stored) }.to raise_error(OpenSSL::Cipher::CipherError)
      end
    end

    context 'when several keys decrypt an aes-256-cbc value' do
      it 'raises' do
        column = described_class.new(Ci::Variable, :value)
        stored = stored_values(create_with_key(old_key) { create(:ci_variable, project: project) }, column)
        stub_db_key_base_keys(old_key, new_key)
        allow(Ci::Variable).to receive(:attr_encrypted_decrypt).and_wrap_original do |method, *args|
          args.last[:key] == new_key ? "\xFF".b.force_encoding(Encoding::UTF_8) : method.call(*args)
        end
        allow(Ci::Variable).to receive(:attr_encrypted_plausible_value?).and_return(true)

        expect { column.reencrypt(stored) }.to raise_error(Gitlab::EncryptedAttribute::AmbiguousDecryptionError)
      end
    end

    context 'when the new value does not decrypt' do
      it 'raises instead of returning it' do
        column = described_class.new(ProjectHook, :url)
        stored = stored_values(create_with_key(old_key) do
          create(:project_hook, project: project, url: 'https://example.com/hook')
        end, column)
        stub_db_key_base_keys(old_key, new_key)
        allow(ProjectHook).to receive(:attr_encrypted_encrypt).and_wrap_original do |method, *args|
          method.call(*args).tap { |value| value[0] = value[0] == 'A' ? 'B' : 'A' }
        end

        expect { column.reencrypt(stored) }.to raise_error(OpenSSL::Cipher::CipherError)
      end
    end

    context 'when the new value decrypts to other bytes' do
      it 'raises instead of returning it' do
        column = described_class.new(ProjectHook, :url)
        stored = stored_values(create_with_key(old_key) do
          create(:project_hook, project: project, url: 'https://example.com/hook')
        end, column)
        stub_db_key_base_keys(old_key, new_key)
        allow(ProjectHook).to receive(:attr_encrypted_encrypt).and_wrap_original do |method, attribute, _, options|
          method.call(attribute, 'https://example.com/tampered', options)
        end

        expect { column.reencrypt(stored) }
          .to raise_error(OpenSSL::Cipher::CipherError, "ProjectHook#url doesn't decrypt after re-encryption")
      end
    end
  end
end
