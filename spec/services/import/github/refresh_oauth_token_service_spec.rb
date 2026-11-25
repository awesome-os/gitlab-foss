# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::Github::RefreshOauthTokenService, :freeze_time, feature_category: :importers do
  include ExclusiveLeaseHelpers

  let_it_be_with_reload(:project) { create(:project, :github_import) }

  let(:token_url) { 'https://github.com/login/oauth/access_token' }
  let(:config) do
    Gitlab::Configs::Options.build(
      'app_id' => 'app-id',
      'app_secret' => 'app-secret',
      'args' => { 'client_options' => { 'site' => 'https://api.github.com', 'token_url' => token_url } }
    )
  end

  let(:credentials) do
    {
      user: 'ghu_old',
      refresh_token: 'ghr_old',
      expires_at: 1.hour.from_now.to_i,
      refresh_token_expires_at: 1.month.from_now.to_i
    }
  end

  let(:refresh_response) do
    {
      access_token: 'ghu_new',
      refresh_token: 'ghr_new',
      expires_in: 28800,
      refresh_token_expires_in: 15897600,
      token_type: 'bearer'
    }
  end

  subject(:service) { described_class.new(project) }

  before do
    project.import_data.update!(credentials: credentials)
    allow(Gitlab::Auth::OAuth::Provider).to receive(:config_for).with('github').and_return(config)
  end

  def stub_lease_taken
    stub_exclusive_lease_taken("import:github:oauth_token_refresh:#{project.id}")
    allow_next_instance_of(Gitlab::ExclusiveLeaseHelpers::SleepingLock) { |lock| allow(lock).to receive(:sleep) }
  end

  def stub_refresh(body = refresh_response)
    stub_request(:post, token_url)
      .with(body: hash_including('grant_type' => 'refresh_token', 'refresh_token' => 'ghr_old'))
      .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#refreshable?' do
    it 'is true when a refresh token is stored' do
      expect(service).to be_refreshable
    end

    context 'with a personal access token' do
      let(:credentials) { { user: 'ghp_token' } }

      it 'is false' do
        expect(service).not_to be_refreshable
      end
    end
  end

  describe '#execute' do
    it 'refreshes the token and stores the new access token, refresh token and expiry times' do
      refresh_request = stub_refresh

      expect(service.execute('ghu_old')).to eq('ghu_new')

      expect(refresh_request).to have_been_made.once
      expect(project.import_data.reload.credentials).to eq(
        user: 'ghu_new',
        refresh_token: 'ghr_new',
        expires_at: Time.current.to_i + 28800,
        refresh_token_expires_at: Time.current.to_i + 15897600
      )
      expect(project.reload.unsafe_import_url).to include('ghu_new')
    end

    it 'returns the stored token without calling GitHub when another job already refreshed it' do
      refresh_request = stub_refresh

      expect(service.execute('ghu_older')).to eq('ghu_old')

      expect(refresh_request).not_to have_been_made
    end

    it 'raises the lock error when another job holds the lease for too long' do
      stub_lease_taken

      expect { service.execute('ghu_old') }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
    end

    context 'when GitHub rejects the refresh token' do
      it 'raises BadRefreshTokenError and keeps the stored credentials' do
        stub_refresh(error: 'bad_refresh_token', error_description: 'The refresh token passed is incorrect or expired.')

        expect { service.execute('ghu_old') }
          .to raise_error(described_class::BadRefreshTokenError, /Authorize GitHub again/)
        expect(project.import_data.reload.credentials).to eq(credentials)
      end

      it 'is handled like any other unauthorized response' do
        stub_refresh(error: 'bad_refresh_token')

        expect { service.execute('ghu_old') }.to raise_error(Octokit::Unauthorized)
      end
    end

    it 'lets other GitHub errors through' do
      stub_request(:post, token_url).to_return(status: 500, body: 'oops')

      expect { service.execute('ghu_old') }.to raise_error(OAuth2::Error)
    end

    context 'when no refresh token is stored' do
      let(:credentials) { { user: 'ghp_token' } }

      it 'raises BadRefreshTokenError' do
        expect { service.execute('ghp_token') }.to raise_error(described_class::BadRefreshTokenError)
      end
    end

    context 'when the project has no import data' do
      before do
        project.import_data.destroy!
        project.reload
      end

      it 'raises BadRefreshTokenError' do
        expect { service.execute('ghu_old') }.to raise_error(described_class::BadRefreshTokenError)
      end
    end

    context 'when the GitHub OAuth provider is not configured' do
      let(:config) { nil }

      it 'raises BadRefreshTokenError without calling GitHub' do
        refresh_request = stub_refresh

        expect { service.execute('ghu_old') }.to raise_error(described_class::BadRefreshTokenError)
        expect(refresh_request).not_to have_been_made
      end
    end

    context 'with GitHub Enterprise' do
      let(:token_url) { 'https://ghe.example.com/login/oauth/access_token' }

      it 'uses the token URL from the provider config' do
        refresh_request = stub_refresh

        service.execute('ghu_old')

        expect(refresh_request).to have_been_made.once
      end
    end
  end

  describe '#current_token' do
    it 'returns the stored token when it is not about to expire' do
      expect(service.current_token).to eq('ghu_old')
    end

    context 'when the token is about to expire' do
      let(:credentials) { { user: 'ghu_old', refresh_token: 'ghr_old', expires_at: 2.minutes.from_now.to_i } }

      it 'refreshes it first' do
        stub_refresh

        expect(service.current_token).to eq('ghu_new')
      end

      context 'when the refresh fails for a temporary reason' do
        it 'returns the stored token when another job holds the lease for too long' do
          stub_lease_taken

          expect(service.current_token).to eq('ghu_old')
        end

        it 'returns the stored token when GitHub returns an error' do
          stub_request(:post, token_url).to_return(status: 500, body: 'oops')

          expect(service.current_token).to eq('ghu_old')
        end

        it 'returns the stored token when GitHub times out' do
          stub_request(:post, token_url).to_timeout

          expect(service.current_token).to eq('ghu_old')
        end

        context 'when the stored token has expired' do
          let(:credentials) { { user: 'ghu_old', refresh_token: 'ghr_old', expires_at: 1.minute.ago.to_i } }

          it 'raises the error' do
            stub_request(:post, token_url).to_return(status: 500, body: 'oops')

            expect { service.current_token }.to raise_error(OAuth2::Error)
          end
        end
      end

      it 'raises BadRefreshTokenError when GitHub rejects the refresh token' do
        stub_refresh(error: 'bad_refresh_token')

        expect { service.current_token }.to raise_error(described_class::BadRefreshTokenError)
      end
    end

    context 'with a personal access token' do
      let(:credentials) { { user: 'ghp_token' } }

      it 'returns the stored token' do
        expect(service.current_token).to eq('ghp_token')
      end
    end

    context 'when the project has no import data' do
      before do
        project.import_data.destroy!
        project.reload
      end

      it 'returns nil' do
        expect(service.current_token).to be_nil
      end
    end
  end

  context 'with a linked user credential that never expires' do
    let_it_be(:user) { project.creator }

    let!(:credential) do
      create(:import_user_credential, user: user, access_token: 'ghu_old', refresh_token: nil, expires_at: nil)
    end

    before do
      project.import_data.merge_data('user_credential_id' => credential.id)
      project.import_data.update!(credentials: { user: 'ghu_copy' })
    end

    it 'reads the token from the credential, not the import copy' do
      expect(service.stored_token).to eq('ghu_old')
    end

    it 'does not refresh it' do
      refresh_request = stub_refresh

      expect(service.current_token).to eq('ghu_old')
      expect(refresh_request).not_to have_been_made
    end

    it 'looks up the linked credential once per service' do
      expect(::Import::UserCredential).to receive(:find_by_id).with(credential.id).once.and_call_original

      service.stored_token
      service.current_token
    end

    context 'when the credential token expires' do
      let!(:credential) do
        create(:import_user_credential, user: user, access_token: 'ghu_old', refresh_token: 'ghr_old',
          expires_at: 2.minutes.from_now, refresh_token_expires_at: 1.month.from_now)
      end

      let!(:copy_refresh) do
        stub_request(:post, token_url)
          .with(body: hash_including('refresh_token' => 'ghr_copy'))
          .to_return(status: 200, body: refresh_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      before do
        project.import_data.update!(credentials: { user: 'ghu_copy', refresh_token: 'ghr_copy',
                                                   expires_at: 2.minutes.from_now.to_i })
      end

      it 'uses the import copy, refreshes it there, and leaves the row untouched' do
        expect(service.current_token).to eq('ghu_new')

        expect(copy_refresh).to have_been_made.once
        expect(project.import_data.reload.credentials[:user]).to eq('ghu_new')
        expect(credential.reload.access_token).to eq('ghu_old')
      end

      it 'logs the fallback with the project id' do
        expect(Gitlab::GithubImport::Logger).to receive(:warn)
          .with(hash_including(message: 'Linked GitHub credential expires, using the import copy',
            Labkit::Fields::GL_PROJECT_ID => project.id))
          .at_least(:once)

        service.current_token
      end
    end

    context 'when the credential row is missing' do
      before do
        credential.destroy!
      end

      it 'falls back to the import copy and logs it with the project id' do
        expect(Gitlab::GithubImport::Logger).to receive(:warn)
          .with(hash_including(message: 'Linked GitHub credential not found, using the import copy',
            Labkit::Fields::GL_PROJECT_ID => project.id))
          .at_least(:once)

        expect(service.stored_token).to eq('ghu_copy')
      end
    end

    context 'when the credential belongs to another user than the project creator' do
      let!(:credential) do
        create(:import_user_credential, user: create(:user), access_token: 'ghu_other', refresh_token: nil,
          expires_at: nil)
      end

      it 'uses the import copy and logs once without the token or user id' do
        expect(Gitlab::GithubImport::Logger).to receive(:warn).once.with(
          message: 'Linked GitHub credential belongs to another user, using the import copy',
          Labkit::Fields::GL_PROJECT_ID => project.id,
          user_credential_id: credential.id
        )

        expect(service.stored_token).to eq('ghu_copy')
      end
    end

    context 'when the credential is for another host than the import URL' do
      before do
        allow(project).to receive(:import_url).and_return('https://ghe.example.com/octocat/vim.git')
      end

      it 'uses the import copy, logs without the token, and leaves the row untouched' do
        expect(Gitlab::GithubImport::Logger).to receive(:warn)
          .with(hash_including(message: 'Linked GitHub credential is for another host, using the import copy'))
          .at_least(:once)

        expect(service.stored_token).to eq('ghu_copy')
        expect(credential.reload.access_token).to eq('ghu_old')
      end
    end

    context 'when the credential is for another host than the OAuth config' do
      before do
        credential.update!(provider_host: 'ghe.example.com')
      end

      it 'uses the import copy' do
        expect(service.stored_token).to eq('ghu_copy')
      end
    end

    context 'when the OAuth config URL cannot be parsed' do
      let(:config) do
        Gitlab::Configs::Options.build(
          'app_id' => 'app-id', 'app_secret' => 'app-secret', 'url' => 'http://exa mple.com'
        )
      end

      it 'uses the import copy' do
        expect(service.stored_token).to eq('ghu_copy')
      end
    end

    context 'when the OAuth config has no URL' do
      let(:config) do
        Gitlab::Configs::Options.build('app_id' => 'app-id', 'app_secret' => 'app-secret', 'url' => '')
      end

      it 'reads the credential stored for github.com' do
        expect(service.stored_token).to eq('ghu_old')
      end
    end

    context 'when the OAuth config URL has no host' do
      let(:config) do
        Gitlab::Configs::Options.build(
          'app_id' => 'app-id', 'app_secret' => 'app-secret', 'url' => 'github.example.com'
        )
      end

      it 'uses the import copy' do
        expect(service.stored_token).to eq('ghu_copy')
      end
    end

    context 'when the GitHub OAuth provider is not configured' do
      let(:config) { nil }

      it 'reads the credential stored for github.com' do
        expect(service.stored_token).to eq('ghu_old')
      end
    end

    [nil, 'http://exa mple.com'].each do |import_url|
      context "when the import URL is #{import_url.inspect}" do
        before do
          allow(project).to receive(:import_url).and_return(import_url)
        end

        it 'uses the import copy' do
          expect(service.stored_token).to eq('ghu_copy')
        end
      end
    end

    context 'when the flag is off' do
      before do
        stub_feature_flags(github_import_reuse_user_credential: false)
      end

      it 'uses the import copy' do
        expect(service.stored_token).to eq('ghu_copy')
      end
    end

    describe '#fetch_url' do
      it 'puts the credential token in the import URL' do
        expect(service.fetch_url).to eq('https://ghu_old@github.com')
      end

      it 'does not put the import copy token in the import URL' do
        expect(service.fetch_url).not_to include('ghu_copy')
      end

      context 'when the credential token expires' do
        let!(:credential) do
          create(:import_user_credential, user: user, access_token: 'ghu_old', refresh_token: 'ghr_old',
            expires_at: 2.minutes.from_now, refresh_token_expires_at: 1.month.from_now)
        end

        it 'uses the import copy URL' do
          expect(service.fetch_url).to eq('https://ghu_copy@github.com')
        end
      end

      context 'when the credential row is missing' do
        before do
          credential.destroy!
        end

        it 'uses the import copy URL' do
          expect(service.fetch_url).to eq('https://ghu_copy@github.com')
        end
      end

      context 'when the credential is for another host than the import URL' do
        before do
          allow(project).to receive(:import_url).and_return('https://ghe.example.com/octocat/vim.git')
        end

        it 'uses the import copy URL' do
          expect(service.fetch_url).to eq('https://ghu_copy@ghe.example.com/octocat/vim.git')
        end
      end

      context 'when the flag is off' do
        before do
          stub_feature_flags(github_import_reuse_user_credential: false)
        end

        it 'uses the import copy URL' do
          expect(service.fetch_url).to eq('https://ghu_copy@github.com')
        end
      end
    end

    context 'with credential_only' do
      subject(:service) { described_class.new(project, credential_only: true) }

      it 'reads the token from the credential, ignoring the import copy' do
        expect(service).to be_credential_only
        expect(service.stored_token).to eq('ghu_old')
      end

      context 'when the credential row is missing' do
        before do
          credential.destroy!
        end

        it 'returns no token and does not read the import copy' do
          expect(service).to be_credential_only
          expect(service.current_token).to be_nil
        end
      end

      context 'when the owner is blocked' do
        before do
          blocked = create(:user, :blocked)
          project.update!(creator: blocked)
          credential.update!(user: blocked)
        end

        it 'returns no token and does not read the import copy' do
          expect(service.current_token).to be_nil
        end
      end

      context 'when the credential is for another host than the import URL' do
        before do
          allow(project).to receive(:import_url).and_return('https://ghe.example.com/octocat/vim.git')
        end

        it 'returns no token and does not read the import copy' do
          expect(service.current_token).to be_nil
        end
      end

      context 'when the credential token expires' do
        let!(:credential) do
          create(:import_user_credential, user: user, access_token: 'ghu_old', refresh_token: 'ghr_old',
            expires_at: 2.minutes.from_now, refresh_token_expires_at: 1.month.from_now)
        end

        before do
          project.import_data.update!(credentials: { user: 'ghu_copy', refresh_token: 'ghr_copy',
                                                     expires_at: 2.minutes.from_now.to_i })
        end

        it 'falls back to the import copy instead of failing closed' do
          expect(service).not_to be_credential_only
          expect(service.stored_token).to eq('ghu_copy')
        end
      end

      context 'when the flag is off' do
        before do
          stub_feature_flags(github_import_reuse_user_credential: false)
        end

        it 'reads the import copy, as it does without credential_only' do
          expect(service).not_to be_credential_only
          expect(service.stored_token).to eq('ghu_copy')
        end
      end

      context 'when the link is blank' do
        before do
          project.import_data.update!(data: {})
        end

        it 'reads the import copy' do
          expect(service).not_to be_credential_only
          expect(service.stored_token).to eq('ghu_copy')
        end
      end
    end
  end
end
