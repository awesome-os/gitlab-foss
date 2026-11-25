# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobToken::SigningKey, feature_category: :secrets_management do
  let_it_be(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow(Gitlab::CurrentSettings)
      .to receive(:ci_job_token_signing_key)
      .and_return(rsa_key.to_pem)
  end

  describe '.current' do
    subject(:current) { described_class.current }

    it 'returns the parsed key pair' do
      expect(current.private_key.to_pem).to eq(rsa_key.to_pem)
      expect(current.public_key.to_pem).to eq(rsa_key.public_key.to_pem)
    end

    it 'parses the signing key once and reuses it across calls' do
      allow(OpenSSL::PKey::RSA).to receive(:new).and_call_original

      3.times { described_class.current }

      expect(OpenSSL::PKey::RSA).to have_received(:new).at_most(:once)
    end

    it 'parses the signing key again when the setting changes' do
      expect(current.private_key.to_pem).to eq(rsa_key.to_pem)

      other_key = OpenSSL::PKey::RSA.generate(2048)
      allow(Gitlab::CurrentSettings)
        .to receive(:ci_job_token_signing_key)
        .and_return(other_key.to_pem)

      expect(described_class.current.private_key.to_pem).to eq(other_key.to_pem)
    end

    context 'with an invalid RSA key' do
      before do
        allow(Gitlab::CurrentSettings)
          .to receive(:ci_job_token_signing_key)
          .and_return('invalid_key')
      end

      it 'returns nil and tracks the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(OpenSSL::PKey::RSAError))

        expect(current).to be_nil
      end
    end

    context 'when the signing key is not set' do
      before do
        allow(Gitlab::CurrentSettings)
          .to receive(:ci_job_token_signing_key)
          .and_return(nil)
      end

      it 'raises an error' do
        expect { current }.to raise_error('CI job token signing key is not set')
      end
    end
  end

  describe '#for?' do
    subject(:signing_key) { described_class.current }

    it 'is true only for the PEM it was parsed from' do
      expect(signing_key).to be_for(rsa_key.to_pem)
      expect(signing_key).not_to be_for(OpenSSL::PKey::RSA.generate(2048).to_pem)
    end
  end

  describe '#inspect' do
    subject(:signing_key) { described_class.current }

    it 'filters the key material' do
      expect(signing_key.inspect).to eq('#<Ci::JobToken::SigningKey [FILTERED]>')
    end

    it 'filters the key material from every string conversion' do
      outputs = [signing_key.to_s, [signing_key].inspect, { key: signing_key }.to_s]

      outputs.each do |output|
        expect(output).to include('[FILTERED]')
        expect(output).not_to include('PRIVATE KEY')
      end
    end
  end
end
