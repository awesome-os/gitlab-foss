# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::ImportGithubHelpers, feature_category: :importers do
  subject do
    helper = Class.new.include(described_class).new
    def helper.params = {
      personal_access_token: 'foo',
      github_hostname: 'github.example.com'
    }
    helper
  end

  describe '#client' do
    it 'returns the new github client' do
      expect(subject.client).to be_a(Gitlab::GithubImport::Client)
    end
  end

  describe '#github_host' do
    it 'is the host from the params' do
      expect(subject.github_host).to eq('github.example.com')
    end
  end

  # Continuous sync needs EE, so the helpers are exercised on their own to cover the defaults EE overrides.
  describe '#prepare_continuous_sync!' do
    it 'drops the continuous_sync stage and keeps the other stages' do
      import_params = { optional_stages: { continuous_sync: true, attachments_import: true } }

      subject.prepare_continuous_sync!(import_params)

      expect(import_params[:optional_stages]).to eq({ attachments_import: true })
    end

    it 'does nothing without optional stages' do
      import_params = { optional_stages: nil }

      expect { subject.prepare_continuous_sync!(import_params) }.not_to raise_error
      expect(import_params).to eq({ optional_stages: nil })
    end
  end

  describe '#configure_import_service' do
    it 'leaves the import service unchanged' do
      import_service = instance_double(Import::GithubService)

      expect(subject.configure_import_service(import_service)).to be_nil
    end
  end

  describe '#access_params' do
    it 'makes the passed in personal access token and extra tokens accessible' do
      expect(subject.access_params).to eq({ github_access_token: 'foo' })
    end
  end

  describe '#provider' do
    it 'is GitHub' do
      expect(subject.provider).to eq(:github)
    end
  end

  describe '#provider_unauthorized' do
    it 'raises an error' do
      expect(subject).to receive(:error!).with('Wrong credentials', 401)
      subject.provider_unauthorized
    end
  end

  describe '#too_many_requests' do
    it 'raises an error' do
      expect(subject).to receive(:error!).with('Too Many Requests', 429)
      subject.too_many_requests
    end
  end
end
