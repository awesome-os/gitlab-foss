# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::MobilePush::EncryptedContent, feature_category: :notifications do
  let(:key) { SecureRandom.random_bytes(32) }
  let(:device_token) { SecureRandom.hex(32) }

  describe '.additional_data' do
    it 'joins the contract version, the lowercased token and the issue time' do
      expect(described_class.additional_data(device_token: 'ABCDEF', issued_at: 1_700_000_000))
        .to eq("gitlab-mobile-push/2\nabcdef\n1700000000")
    end
  end

  describe '.seal' do
    subject(:envelope) do
      described_class.seal('{"body":"hi"}', key: key, device_token: device_token, issued_at: 1_700_000_000)
    end

    it 'produces the version-2 envelope' do
      expect(envelope).to include(alg: 'A256GCM', v: 2, iat: 1_700_000_000)
      expect(envelope[:ciphertext]).to match(%r{\A[A-Za-z0-9+/]+=*\z})
    end

    it 'is strict base64 of nonce, ciphertext and tag' do
      combined = Base64.strict_decode64(envelope[:ciphertext])

      expect(combined.bytesize).to eq(12 + '{"body":"hi"}'.bytesize + 16)
    end

    it 'uses a fresh nonce per call' do
      other = described_class.seal('{"body":"hi"}', key: key, device_token: device_token, issued_at: 1_700_000_000)

      expect(other[:ciphertext]).not_to eq(envelope[:ciphertext])
    end
  end
end
