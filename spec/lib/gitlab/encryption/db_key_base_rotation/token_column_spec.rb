# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Encryption::DbKeyBaseRotation::TokenColumn, feature_category: :cell do
  include DbKeyBaseHelpers

  subject(:column) { described_class.new(:token) }

  # Read before any example stubs the keys
  let!(:old_key) { Settings.db_key_base_keys.last }
  let(:new_key) { SecureRandom.hex(64) }
  let(:token) { 'glptt-token' }

  def encrypt_with(key, static_iv: false)
    create_with_key(key) do
      if static_iv
        Gitlab::CryptoHelper.aes256_gcm_encrypt(token)
      else
        Authn::TokenField::EncryptionHelper.encrypt_token(token)
      end
    end
  end

  describe '#columns' do
    it 'is the encrypted token column' do
      expect(column.columns).to eq(%w[token_encrypted])
    end
  end

  describe '#definition' do
    it 'is the encrypted token column' do
      expect(column.definition).to eq(column: 'token_encrypted')
    end
  end

  describe '#reencrypt' do
    context 'when an older key encrypted the token' do
      it 'returns the token encrypted with the current key' do
        stored = encrypt_with(old_key)
        stub_db_key_base_keys(old_key, new_key)

        new_value = column.reencrypt('token_encrypted' => stored)['token_encrypted']

        expect(new_value).to eq(Authn::TokenField::EncryptionHelper.encrypt_token(token))
        expect(new_value).not_to eq(stored)
      end
    end

    context 'when an older key encrypted the token with the static IV' do
      it 'returns the token encrypted with the current key and a dynamic nonce' do
        stored = encrypt_with(old_key, static_iv: true)
        stub_db_key_base_keys(old_key, new_key)

        expect(column.reencrypt('token_encrypted' => stored))
          .to eq('token_encrypted' => Authn::TokenField::EncryptionHelper.encrypt_token(token))
      end
    end

    where(:static_iv) { [false, true] }

    with_them do
      it 'returns nil when the current key encrypted the token' do
        stored = encrypt_with(new_key, static_iv: static_iv)
        stub_db_key_base_keys(old_key, new_key)

        expect(column.reencrypt('token_encrypted' => stored)).to be_nil
      end
    end

    context 'when the token is empty' do
      it 'returns nil' do
        expect(column.reencrypt('token_encrypted' => nil)).to be_nil
      end
    end

    context 'when the token decrypts to an empty string' do
      it 'raises' do
        stored = create_with_key(old_key) { Authn::TokenField::EncryptionHelper.encrypt_token('') }
        stub_db_key_base_keys(old_key, new_key)

        expect { column.reencrypt('token_encrypted' => stored) }
          .to raise_error(OpenSSL::Cipher::CipherError, 'token_encrypted decrypts to an empty token')
      end
    end

    context 'when no key decrypts the token' do
      it 'raises' do
        stored = encrypt_with(SecureRandom.hex(64))
        stub_db_key_base_keys(old_key, new_key)

        expect { column.reencrypt('token_encrypted' => stored) }.to raise_error(OpenSSL::Cipher::CipherError)
      end
    end

    context 'when the new value decrypts to another token' do
      it 'raises instead of returning it' do
        stored = encrypt_with(old_key)
        stub_db_key_base_keys(old_key, new_key)
        allow(Authn::TokenField::EncryptionHelper).to receive(:encrypt_token).and_wrap_original do |method, token|
          method.call("#{token}-tampered")
        end

        expect { column.reencrypt('token_encrypted' => stored) }
          .to raise_error(OpenSSL::Cipher::CipherError, "token_encrypted doesn't decrypt after re-encryption")
      end
    end
  end
end
