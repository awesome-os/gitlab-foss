# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::Github::FindUsableUserCredentialService, :freeze_time, feature_category: :importers do
  let_it_be(:user) { create(:user) }
  let!(:credential) do
    create(:import_user_credential, user: user, provider_account_xid: 583231, access_token: 'ghu_token')
  end

  subject(:execute) { described_class.new(user, provider_host: 'github.com').execute }

  before do
    stub_request(:get, 'https://api.github.com/user')
      .with(headers: { 'Authorization' => 'token ghu_token' })
      .to_return(status: 200, body: { id: 583231, login: 'octocat' }.to_json,
        headers: { 'Content-Type' => 'application/json' })
  end

  it 'returns the stored credential' do
    expect(execute).to be_success
    expect(execute.payload).to eq(credential: credential, login: 'octocat')
  end

  context 'when the user has no credential for the host' do
    subject(:execute) { described_class.new(user, provider_host: 'ghe.example.com').execute }

    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.message).to eq('no stored credential')
    end
  end

  context 'when the credential lacks a required scope' do
    before do
      credential.update!(scopes: 'repo')
    end

    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.message).to eq('missing scopes')
    end
  end

  context 'when the token expires' do
    shared_examples 'reports an expiring token' do
      it 'returns an error without calling GitHub' do
        expect(execute).to be_error
        expect(execute.message).to eq('expiring token')
        expect(a_request(:get, 'https://api.github.com/user')).not_to have_been_made
      end
    end

    context 'when the credential has a refresh token' do
      before do
        credential.update!(refresh_token: 'ghr_token')
      end

      it_behaves_like 'reports an expiring token'
    end

    context 'when the credential has an expiry' do
      before do
        credential.update!(expires_at: 1.hour.from_now)
      end

      it_behaves_like 'reports an expiring token'
    end
  end

  context 'when GitHub rejects the token' do
    before do
      stub_request(:get, 'https://api.github.com/user').to_return(status: 401)
    end

    it 'returns an error and keeps the credential' do
      expect(Gitlab::GithubImport::Logger).to receive(:info)
        .with(hash_including(message: 'Not reusing stored GitHub OAuth credential: token rejected'))
        .and_wrap_original do |method, payload|
          expect(payload.to_s).not_to include('ghu_token')
          method.call(payload)
        end

      expect(execute).to be_error
      expect(Import::UserCredential.exists?(credential.id)).to be(true)
    end
  end

  context 'when GitHub fails with another API error' do
    before do
      stub_request(:get, 'https://api.github.com/user').to_return(status: 500)
    end

    it 'reports the error class without the token' do
      expect(Gitlab::GithubImport::Logger).to receive(:info)
        .with(hash_including(message: 'Not reusing stored GitHub OAuth credential: GitHub API error: Octokit::InternalServerError'))
        .and_wrap_original do |method, payload|
          expect(payload.to_s).not_to include('ghu_token')
          method.call(payload)
        end

      expect(execute).to be_error
    end
  end

  context 'when the token now belongs to another GitHub account' do
    before do
      stub_request(:get, 'https://api.github.com/user')
        .to_return(status: 200, body: { id: 1 }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'reports an account mismatch' do
      expect(Gitlab::GithubImport::Logger).to receive(:info)
        .with(hash_including(message: 'Not reusing stored GitHub OAuth credential: account mismatch'))

      expect(execute).to be_error
    end
  end

  context 'when the user has two credentials for the host' do
    let!(:newer_credential) do
      create(:import_user_credential, user: user, provider_account_xid: 99, access_token: 'ghu_newer')
    end

    before do
      credential.update!(updated_at: 1.day.ago)
      stub_request(:get, 'https://api.github.com/user')
        .with(headers: { 'Authorization' => 'token ghu_newer' })
        .to_return(status: 200, body: { id: 99, login: 'hubot' }.to_json,
          headers: { 'Content-Type' => 'application/json' })
    end

    it 'uses the most recently updated credential' do
      expect(execute.payload).to eq(credential: newer_credential, login: 'hubot')
    end
  end
end
