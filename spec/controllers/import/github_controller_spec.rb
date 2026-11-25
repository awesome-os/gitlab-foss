# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::GithubController, feature_category: :importers do
  include ImportSpecHelper

  let(:provider) { :github }
  let(:new_import_url) { public_send("new_import_#{provider}_url") }

  include_context 'a GitHub-ish import controller'

  describe "GET new" do
    it_behaves_like 'a GitHub-ish import controller: GET new'

    it "renders the landing page even when logged in with GitHub" do
      expect(controller).not_to receive(:go_to_provider_for_permissions)

      get :new

      expect(response).to render_template(:new)
    end

    it "prompts for an access token if GitHub not configured" do
      allow(controller).to receive(:github_import_configured?).and_return(false)
      expect(controller).not_to receive(:go_to_provider_for_permissions)

      get :new

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when importing a CI/CD project' do
      it 'always prompts for an access token' do
        allow(controller).to receive(:github_import_configured?).and_return(true)

        get :new, params: { ci_cd_only: true }

        expect(response).to render_template(:new)
      end
    end

    it 'gets authorization url using oauth client' do
      expect(controller).to receive(:go_to_provider_for_permissions).and_call_original
      expect_next_instance_of(OAuth2::Client) do |client|
        expect(client.auth_code).to receive(:authorize_url).and_call_original
      end

      get :status
    end
  end

  describe "reusing a stored GitHub credential" do
    let(:access_token) { 'ghu_stored' }
    let(:scopes) { 'repo,read:org' }
    let(:refresh_token) { nil }
    let(:expires_at) { nil }
    let!(:credential) do
      create(:import_user_credential, user: user, provider_account_xid: 583231, access_token: access_token,
        refresh_token: refresh_token, scopes: scopes, expires_at: expires_at)
    end

    before do
      stub_feature_flags(github_import_reuse_user_credential: true)
      allow(controller).to receive(:github_import_configured?).and_return(true)
      stub_request(:get, 'https://api.github.com/user')
        .with(headers: { 'Authorization' => "token #{access_token}" })
        .to_return(status: 200, body: { id: 583231, login: 'octocat' }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    context 'with a usable credential' do
      it 'continues to status without redirecting to GitHub' do
        expect(controller).not_to receive(:go_to_provider_for_permissions)

        get :new

        expect(response).to redirect_to(status_import_github_url)
        expect(session[:github_access_token]).to be_nil
        expect(session[:github_oauth_token]).to be(true)
        expect(session[:github_reused_user_login]).to eq('octocat')
        expect(session[:github_user_credential_id]).to eq(credential.id)
      end

      it 'reuses the credential on status without a session token' do
        expect(controller).not_to receive(:go_to_provider_for_permissions)

        get :status

        expect(response).to have_gitlab_http_status(:ok)
        expect(session[:github_access_token]).to be_nil
        expect(session[:github_user_credential_id]).to eq(credential.id)
      end

      it 'continues realtime changes without a session token' do
        get :realtime_changes, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(session[:github_access_token]).to be_nil
      end

      it 'does not check GitHub again on new while the credential is in use' do
        session[:github_user_credential_id] = credential.id

        expect(Import::Github::FindUsableUserCredentialService).not_to receive(:new)

        get :new

        expect(response).to redirect_to(status_import_github_url)
      end

      it 'does not check GitHub again on realtime polls while the credential is in use' do
        get :new

        expect(Import::Github::FindUsableUserCredentialService).not_to receive(:new)

        get :realtime_changes, format: :json
      end

      it 'lists repos with the token from the stored credential' do
        proxy = instance_double(Gitlab::GithubImport::Clients::Proxy,
          repos: { repos: [], page_info: {}, count: 0 })
        expect(Gitlab::GithubImport::Clients::Proxy).to receive(:new).with(access_token).and_return(proxy)

        get :status, format: :json

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'links the stored credential when creating an import' do
        service = instance_double(Import::GithubService, :request_channel= => nil)
        expect(Import::GithubService).to receive(:new).and_return(service)
        expect(service).to receive(:execute).with(
          hash_including(github_access_token: access_token, user_credential_id: credential.id), :github
        ).and_return({ status: :error, http_status: :unprocessable_entity })

        post :create, params: { target_namespace: user.namespace_path }, format: :json
      end

      it 'uses the most recently updated credential when there are several accounts' do
        create(:import_user_credential, user: user, provider_account_xid: 99, access_token: 'ghu_older',
          updated_at: 1.day.ago)
        credential.update!(updated_at: 1.hour.ago)
        stub_request(:get, 'https://api.github.com/user')
          .with(headers: { 'Authorization' => 'token ghu_stored' })
          .to_return(status: 200, body: { id: 583231, login: 'octocat' }.to_json, headers: { 'Content-Type' => 'application/json' })

        get :new

        expect(session[:github_user_credential_id]).to eq(credential.id)
      end

      it 'forces OAuth when reauthorize is requested' do
        expect(controller).to receive(:go_to_provider_for_permissions)

        get :new, params: { reauthorize: true }

        expect(session[:github_access_token]).to be_nil
      end

      it 'does not reuse the credential on status when reauthorize is requested' do
        expect(controller).to receive(:go_to_provider_for_permissions)

        get :status, params: { reauthorize: true }

        expect(session[:github_access_token]).to be_nil
      end

      it 'exposes the reused login while the reused credential is in use' do
        get :new

        expect(controller.send(:reused_user_login)).to eq('octocat')
      end

      it 'leaves no refresh details in the session, even a stale one' do
        session[:github_refresh_credentials] = { 'refresh_token' => 'ghr_earlier' }

        get :new

        expect(session[:github_access_token]).to be_nil
        expect(session[:github_refresh_credentials]).to be_nil
      end

      it 'logs one reuse entry with the user ID and no token or login', :aggregate_failures do
        expect(Gitlab::GithubImport::Logger).to receive(:info).once do |payload|
          expect(payload).to include(Labkit::Fields::GL_USER_ID => user.id)
          expect(payload.to_s).not_to include('ghu_stored', 'octocat')
        end

        get :new
      end
    end

    context 'when impersonating' do
      before do
        session[:impersonator_id] = create(:admin).id
      end

      it 'does not reuse the stored credential on new' do
        get :new

        expect(response).to render_template(:new)
        expect(session[:github_access_token]).to be_nil
        expect(session[:github_reused_user_login]).to be_nil
      end

      it 'does not reuse the stored credential on status' do
        expect(controller).to receive(:go_to_provider_for_permissions)

        get :status

        expect(session[:github_access_token]).to be_nil
      end
    end

    context 'when a blank personal access token is in the session' do
      before do
        session[:github_access_token] = ''
      end

      it 'uses the token of the reused credential for the client' do
        proxy = instance_double(Gitlab::GithubImport::Clients::Proxy,
          repos: { repos: [], page_info: {}, count: 0 })
        expect(Gitlab::GithubImport::Clients::Proxy).to receive(:new).with(access_token).and_return(proxy)

        get :status, format: :json

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the reuse flag is turned off after a reuse' do
      it 'redirects to status while the credential id is in the session' do
        get :new
        stub_feature_flags(github_import_reuse_user_credential: false)

        get :new

        expect(response).to redirect_to(status_import_github_url)
      end
    end

    context 'when the session holds another user credential id' do
      let(:other_user) { create(:user) }
      let!(:other_credential) do
        create(:import_user_credential, user: other_user, provider_account_xid: 4242, access_token: 'ghu_other',
          scopes: scopes)
      end

      before do
        # Leave the user without a usable credential of their own, so only the session ID could supply a token
        credential.destroy!
        session[:github_user_credential_id] = other_credential.id
      end

      it 'does not use the other user token and renders the landing page' do
        expect(Gitlab::GithubImport::Clients::Proxy).not_to receive(:new).with('ghu_other')

        get :new

        expect(response).to render_template(:new)
        expect(session[:github_access_token]).to be_nil
        expect(session[:github_user_credential_id]).to be_nil
      end

      it 'does not list repos with the other user token' do
        expect(Gitlab::GithubImport::Clients::Proxy).not_to receive(:new).with('ghu_other')

        get :status, format: :json
      end
    end

    context 'when the session holds a credential id that no longer exists' do
      before do
        credential.destroy!
        session[:github_user_credential_id] = non_existing_record_id
      end

      it 'renders the landing page without a token' do
        get :new

        expect(response).to render_template(:new)
        expect(session[:github_access_token]).to be_nil
        expect(session[:github_user_credential_id]).to be_nil
      end
    end

    context 'when a personal access token is already in the session' do
      before do
        session[:github_access_token] = 'glpat_personal'
      end

      it 'keeps the token and redirects to status without reusing or redirecting to GitHub' do
        expect(controller).not_to receive(:go_to_provider_for_permissions)

        get :new

        expect(response).to redirect_to(status_import_github_url)
        expect(session[:github_access_token]).to eq('glpat_personal')
      end
    end

    context 'when the session holds only a reused credential id' do
      before do
        session[:github_user_credential_id] = credential.id
      end

      it 'redirects to status on a CI/CD project' do
        get :new, params: { ci_cd_only: true }

        expect(response).to have_gitlab_http_status(:redirect)
        expect(response.location).to start_with(status_import_github_url)
      end

      it 'redirects to status when GitHub is not configured' do
        allow(controller).to receive(:github_import_configured?).and_return(false)

        get :new

        expect(response).to redirect_to(status_import_github_url)
      end
    end

    context 'when importing a CI/CD project' do
      it 'does not reuse the credential or redirect' do
        expect(controller).not_to receive(:go_to_provider_for_permissions)

        get :new, params: { ci_cd_only: true }

        expect(response).to render_template(:new)
        expect(session[:github_access_token]).to be_nil
      end

      it 'does not reuse the credential on status' do
        get :status, params: { ci_cd_only: true }

        expect(session[:github_access_token]).to be_nil
      end
    end

    context 'when a request reads the reused credential several times' do
      render_views

      it 'looks up the stored credential once' do
        session[:github_user_credential_id] = credential.id

        recorder = ActiveRecord::QueryRecorder.new { get :status }

        expect(recorder.log.grep(/import_user_credentials/).size).to eq(1)
      end

      it 'sees a credential ID that is set after an earlier lookup' do
        other_credential = create(:import_user_credential, user: user, provider_account_xid: 583232,
          access_token: 'ghu_second', scopes: scopes)
        session[:github_user_credential_id] = credential.id
        expect(controller.send(:reused_user_credential)).to eq(credential)

        session[:github_user_credential_id] = other_credential.id

        expect(controller.send(:reused_user_credential)).to eq(other_credential)
      end
    end

    context 'when a credential ID is already in the session' do
      it 'returns true without asking GitHub again' do
        session[:github_user_credential_id] = credential.id
        expect(Import::Github::FindUsableUserCredentialService).not_to receive(:new)

        expect(controller.send(:reuse_user_credential)).to be(true)
      end
    end

    context 'when the reused credential id is cleared' do
      it 'does not expose the reused login' do
        get :new

        session.delete(:github_user_credential_id)

        expect(controller.send(:reused_user_login)).to be_nil
      end
    end

    context 'when the listing rejects the reused token' do
      before do
        get :new
        allow(controller).to receive(:client_repos_response).and_raise(listing_error)
        get :status, format: :json
      end

      context 'when GitHub forbids the listing' do
        let(:listing_error) { Octokit::Forbidden.new }

        it 'drops the reused credential id' do
          expect(session[:github_user_credential_id]).to be_nil
        end

        it 'renders the landing page on the next visit to new instead of redirecting back' do
          expect(session[:github_access_token]).to be_nil

          get :new

          expect(response).to render_template(:new)
          expect(session[:github_access_token]).to be_nil
        end

        it 'reuses the credential again after a fresh OAuth callback' do
          allow_next_instance_of(OAuth2::Client) do |client|
            allow(client).to receive_message_chain(:auth_code, :get_token)
              .and_return(OAuth2::AccessToken.from_hash(client, { 'access_token' => 'ghu_new' }))
          end
          allow(Import::Github::StoreUserCredentialService).to receive(:new)
            .and_return(instance_double(Import::Github::StoreUserCredentialService, execute: ServiceResponse.success))
          stub_feature_flags(github_continuous_import: false)
          session[:github_auth_state_key] = 'secret-state'

          get :callback, params: { state: 'secret-state' }
          session.delete(:github_access_token)
          get :new

          expect(session[:github_user_credential_id]).to eq(credential.id)
        end
      end

      context 'when GitHub rate limits the listing' do
        let(:listing_error) { Octokit::TooManyRequests.new(response_headers: { 'x-ratelimit-reset' => '0' }) }

        it 'drops the reused credential id' do
          expect(session[:github_user_credential_id]).to be_nil
        end

        it 'shows the rate limit alert' do
          expect(flash[:alert]).to include('GitHub API rate limit exceeded')
        end

        it 'renders the landing page on the next visit to new instead of redirecting back' do
          expect(session[:github_access_token]).to be_nil

          get :new

          expect(response).to render_template(:new)
          expect(session[:github_access_token]).to be_nil
        end
      end

      context 'when GitHub rejects the token on the listing' do
        let(:listing_error) { Octokit::Unauthorized.new }

        it 'drops the reused credential id' do
          expect(session[:github_user_credential_id]).to be_nil
        end

        it 'renders the landing page on the next visit to new instead of redirecting back' do
          expect(session[:github_access_token]).to be_nil

          get :new

          expect(response).to render_template(:new)
          expect(session[:github_access_token]).to be_nil
        end
      end
    end

    context 'when the reuse flag is off' do
      before do
        stub_feature_flags(github_import_reuse_user_credential: false)
        session[:github_access_token] = 'ghu_oauth'
        session[:github_reused_user_login] = 'octocat'
      end

      it 'does not expose the account data' do
        expect(controller.send(:reused_user_login)).to be_nil
        expect(controller.send(:github_account_data)).to eq({})
      end
    end

    context 'when the status page is ci_cd_only' do
      it 'does not expose the account data' do
        session[:github_access_token] = 'ghu_stored'
        session[:github_reused_user_login] = 'octocat'

        get :status, params: { ci_cd_only: true }

        expect(controller.send(:github_account_data)).to eq({})
      end
    end

    context 'when the status page is for a namespace' do
      it 'keeps the namespace in the reauthorize link' do
        group = create(:group)
        group.add_owner(user)
        session[:github_access_token] = 'ghu_stored'
        session[:github_reused_user_login] = 'octocat'

        get :status, params: { namespace_id: group.id }

        expect(controller.send(:github_account_data)[:github_reauthorize_path])
          .to eq(new_import_github_path(reauthorize: true, namespace_id: group.id))
      end
    end

    context 'when reauthorizing' do
      before do
        session[:github_access_token] = 'ghu_stored'
        session[:github_oauth_token] = true
        session[:github_refresh_credentials] = { 'refresh_token' => 'ghr_stored' }
        session[:github_reused_user_login] = 'octocat'
        session[:github_user_credential_id] = credential.id
      end

      it 'clears the session token and redirects to GitHub without a GitHub identity' do
        expect(controller).to receive(:go_to_provider_for_permissions)

        get :new, params: { reauthorize: true }

        expect(session[:github_access_token]).to be_nil
        expect(session[:github_oauth_token]).to be_nil
        expect(session[:github_refresh_credentials]).to be_nil
        expect(session[:github_reused_user_login]).to be_nil
        expect(session[:github_user_credential_id]).to be_nil
      end

      it 'asks GitHub for the account picker' do
        expect_next_instance_of(OAuth2::Client) do |client|
          expect(client.auth_code).to receive(:authorize_url)
            .with(hash_including(prompt: 'select_account')).and_call_original
        end

        get :new, params: { reauthorize: true }
      end
    end

    context 'when not reauthorizing' do
      before do
        stub_feature_flags(github_import_reuse_user_credential: false)
      end

      it 'does not ask GitHub for the account picker' do
        expect_next_instance_of(OAuth2::Client) do |client|
          expect(client.auth_code).to receive(:authorize_url)
            .with(hash_not_including(:prompt)).and_call_original
        end

        get :status
      end
    end

    context 'when the credential is not usable' do
      shared_examples 'falls back to OAuth' do
        it 'redirects to GitHub and does not put the stored token in the session' do
          expect(controller).to receive(:go_to_provider_for_permissions)

          get :status

          expect(session[:github_access_token]).to be_nil
        end
      end

      context 'when it lacks a required scope' do
        let(:scopes) { 'repo' }

        it_behaves_like 'falls back to OAuth'
      end

      context 'when it has a refresh token' do
        let(:refresh_token) { 'ghr_stored' }

        it_behaves_like 'falls back to OAuth'
      end

      context 'when it expires' do
        let(:expires_at) { 1.hour.from_now }

        it_behaves_like 'falls back to OAuth'
      end

      context 'when GitHub rejects the token' do
        before do
          stub_request(:get, 'https://api.github.com/user').to_return(status: 401)
        end

        it_behaves_like 'falls back to OAuth'
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(github_import_reuse_user_credential: false)
      end

      it 'renders the landing page without a token' do
        expect(controller).not_to receive(:go_to_provider_for_permissions)

        get :new

        expect(response).to render_template(:new)
        expect(session[:github_access_token]).to be_nil
      end

      it 'redirects to GitHub from status as before' do
        expect(controller).to receive(:go_to_provider_for_permissions)

        get :status
      end
    end

    context 'when the OAuth flow completes' do
      let(:oauth_token_response) { { 'access_token' => 'ghu_new' } }

      before do
        stub_feature_flags(github_continuous_import: false)
        allow_next_instance_of(OAuth2::Client) do |client|
          allow(client).to receive_message_chain(:auth_code, :get_token)
            .and_return(OAuth2::AccessToken.from_hash(client, oauth_token_response))
        end
        session[:github_auth_state_key] = 'secret-state'
        session[:github_reused_user_login] = 'octocat'
      end

      it 'stores the credential even with continuous import disabled' do
        expect(Import::Github::StoreUserCredentialService).to receive(:new)
          .and_return(instance_double(Import::Github::StoreUserCredentialService, execute: ServiceResponse.success))

        get :callback, params: { state: 'secret-state' }

        expect(session[:github_reused_user_login]).to be_nil
      end
    end
  end

  describe "GET callback" do
    context "when auth state param is missing from session" do
      it "reports an error" do
        get :callback

        expect(controller).to redirect_to(new_import_url)
        expect(flash[:alert]).to eq('Invalid credentials')
      end
    end

    context "when auth state param is present in session" do
      let(:valid_auth_state) { "secret-state" }

      let(:oauth_token_response) { { 'access_token' => token } }

      before do
        allow_next_instance_of(OAuth2::Client) do |client|
          allow(client).to receive_message_chain(:auth_code, :get_token)
            .and_return(OAuth2::AccessToken.from_hash(client, oauth_token_response))
        end
        allow(Import::Github::StoreUserCredentialService).to receive(:new)
          .and_return(instance_double(Import::Github::StoreUserCredentialService, execute: ServiceResponse.success))
        session[:github_auth_state_key] = valid_auth_state
      end

      it "reports an error if state param is invalid" do
        get :callback, params: { state: "different-state" }

        expect(controller).to redirect_to(new_import_url)
        expect(flash[:alert]).to eq('Invalid credentials')
      end

      it "updates access token if state param is valid" do
        token = "asdasd12345"

        get :callback, params: { state: valid_auth_state }

        expect(session[:github_access_token]).to eq(token)
        expect(session[:github_oauth_token]).to be(true)
        expect(session[:github_refresh_credentials]).to eq({})
        expect(controller).to redirect_to(status_import_github_url)
      end

      context 'when GitHub returns an expiring token', :freeze_time do
        let(:oauth_token_response) do
          {
            'access_token' => token,
            'refresh_token' => 'ghr_token',
            'expires_in' => 28800,
            'refresh_token_expires_in' => 15897600
          }
        end

        it 'stores the refresh token and both expiry times' do
          get :callback, params: { state: valid_auth_state }

          expect(session[:github_access_token]).to eq(token)
          expect(session[:github_refresh_credentials]).to eq(
            'refresh_token' => 'ghr_token',
            'expires_at' => Time.current.to_i + 28800,
            'refresh_token_expires_at' => Time.current.to_i + 15897600
          )
        end
      end

      it 'stores the OAuth credential for the user' do
        get :callback, params: { state: valid_auth_state }

        expect(Import::Github::StoreUserCredentialService).to have_received(:new)
          .with(user, having_attributes(token: token), provider_host: 'github.com')
      end

      context 'when GitHub Enterprise is configured' do
        before do
          allow(Gitlab::Auth::OAuth::Provider).to receive(:config_for).with('github').and_return(
            Gitlab::Configs::Options.build('app_id' => 'id', 'app_secret' => 'secret', 'url' => 'https://ghe.example.com/')
          )
        end

        it 'stores the OAuth credential for the GitHub Enterprise host' do
          get :callback, params: { state: valid_auth_state }

          expect(Import::Github::StoreUserCredentialService).to have_received(:new)
            .with(user, anything, provider_host: 'ghe.example.com')
        end
      end

      context 'when the configured GitHub URL has no host' do
        where(:url) { ['ghe.example.com', 'https://ghe.example.com:port'] }

        with_them do
          before do
            allow(Gitlab::Auth::OAuth::Provider).to receive(:config_for).with('github').and_return(
              Gitlab::Configs::Options.build('app_id' => 'id', 'app_secret' => 'secret', 'url' => url)
            )
          end

          it 'does not store the OAuth credential' do
            get :callback, params: { state: valid_auth_state }

            expect(Import::Github::StoreUserCredentialService).not_to have_received(:new)
            expect(controller).to redirect_to(status_import_github_url)
          end
        end
      end

      context 'when github_continuous_import is disabled' do
        before do
          stub_feature_flags(github_continuous_import: false)
          # Unstubbed flags are on in specs; keep this example off the reuse store path
          stub_feature_flags(github_import_reuse_user_credential: false)
        end

        it 'does not store the OAuth credential' do
          expect(Import::Github::StoreUserCredentialService).not_to receive(:new)

          get :callback, params: { state: valid_auth_state }

          expect(session[:github_access_token]).to eq(token)
        end
      end

      it "includes namespace_id from query params if it is present" do
        namespace_id = 1

        get :callback, params: { state: valid_auth_state, namespace_id: namespace_id }

        expect(controller).to redirect_to(status_import_github_url(namespace_id: namespace_id))
      end

      context 'when the OAuth callback stores the credential' do
        before do
          stub_feature_flags(github_import_reuse_user_credential: true)
          allow(Import::Github::StoreUserCredentialService).to receive(:new).and_call_original
          stub_request(:get, 'https://api.github.com/user')
            .with(headers: { 'Authorization' => "token #{token}" })
            .to_return(status: 200, body: { id: 583231, login: 'octocat' }.to_json,
              headers: { 'Content-Type' => 'application/json' })
        end

        it 'keeps the GitHub login in session for the status page' do
          get :callback, params: { state: valid_auth_state }

          expect(session[:github_reused_user_login]).to eq('octocat')
        end

        it 'keeps the stored credential id in session for the import' do
          get :callback, params: { state: valid_auth_state }

          expect(session[:github_user_credential_id]).to eq(Import::UserCredential.last.id)
        end
      end

      context 'when impersonating during the OAuth callback' do
        before do
          stub_feature_flags(github_import_reuse_user_credential: true)
          allow(Import::Github::StoreUserCredentialService).to receive(:new).and_call_original
          stub_request(:get, 'https://api.github.com/user')
            .with(headers: { 'Authorization' => "token #{token}" })
            .to_return(status: 200, body: { id: 583231, login: 'octocat' }.to_json,
              headers: { 'Content-Type' => 'application/json' })
          session[:impersonator_id] = create(:admin).id
        end

        it 'does not store the credential or keep a login in session' do
          expect(Import::Github::StoreUserCredentialService).not_to receive(:new)

          expect { get :callback, params: { state: valid_auth_state } }.not_to change { Import::UserCredential.count }

          expect(session[:github_access_token]).to eq(token)
          expect(session[:github_reused_user_login]).to be_nil
        end
      end
    end
  end

  describe "POST personal_access_token" do
    it_behaves_like 'a GitHub-ish import controller: POST personal_access_token'

    it 'clears the OAuth marker from a previous OAuth session' do
      session[:github_oauth_token] = true

      post :personal_access_token, params: { personal_access_token: 'pat' }

      expect(session[:github_oauth_token]).to be_nil
    end

    it 'clears the refresh credentials from a previous OAuth session' do
      session[:github_refresh_credentials] = { 'refresh_token' => 'ghr_token' }

      post :personal_access_token, params: { personal_access_token: 'pat' }

      expect(session[:github_refresh_credentials]).to be_nil
    end

    it 'clears the stored credential id from a previous OAuth session' do
      session[:github_user_credential_id] = non_existing_record_id

      post :personal_access_token, params: { personal_access_token: 'pat' }

      expect(session[:github_user_credential_id]).to be_nil
    end
  end

  describe "GET status" do
    shared_examples 'calls repos through Clients::Proxy with expected args' do
      it 'calls repos list from provider with expected args' do
        expect_next_instance_of(Gitlab::GithubImport::Clients::Proxy) do |client|
          expect(client).to receive(:repos)
            .and_return({ repos: [], page_info: {}, count: 0 })
        end

        get :status, params: params, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['imported_projects'].size).to eq 0
        expect(json_response['provider_repos'].size).to eq 0
        expect(json_response['incompatible_repos'].size).to eq 0
        expect(json_response['page_info']).to eq({})
        expect(json_response['provider_repo_count']).to eq(0)
      end
    end

    let(:provider_token) { 'asdasd12345' }
    let(:client_auth_success) { true }
    let(:client_stub) { instance_double(Gitlab::GithubImport::Client, user: { login: 'user' }) }
    let(:params) { nil }
    let(:pagination_params) { { before: nil, after: nil } }
    let(:relation_params) { { relation_type: nil, organization_login: '' } }
    let(:provider_repos) { [] }

    before do
      allow_next_instance_of(Gitlab::GithubImport::Clients::Proxy) do |proxy|
        if client_auth_success
          allow(proxy).to receive_messages(repos: { repos: provider_repos }, client: client_stub)
          allow_next_instance_of(Gitlab::GithubImport::ProjectRelationType) do |instance|
            allow(instance).to receive(:for).with('example/repo').and_return('owned')
          end
        elsif client_scope_error
          allow(proxy).to receive(:repos).and_raise(Octokit::Forbidden)
        else
          allow(proxy).to receive(:repos).and_raise(Octokit::Unauthorized)
        end
      end
      session[:"#{provider}_access_token"] = provider_token
    end

    context 'with OAuth' do
      let(:provider_token) { nil }

      context 'when OAuth config is missing' do
        before do
          allow(controller).to receive(:oauth_config).and_return(nil)
        end

        it 'returns missing config error' do
          expect(controller).to receive(:go_to_provider_for_permissions).and_call_original

          get :status

          expect(session[:"#{provider}_access_token"]).to be_nil
          expect(controller).to redirect_to(new_import_url)
          expect(flash[:alert]).to eq('Missing OAuth configuration for GitHub.')
        end
      end
    end

    context 'with invalid auth token' do
      let(:client_auth_success) { false }
      let(:client_scope_error) { false }

      it "handles the error" do
        get :status, format: :json

        expect(session[:"#{provider}_access_token"]).to be_nil
        expect(json_response.dig("error", "redirect")).to eq(new_import_url)
        expect(flash[:alert]).to eq("Invalid credentials")
      end
    end

    context 'with invalid access token' do
      let(:client_auth_success) { false }
      let(:client_scope_error) { true }
      let(:docs_link) do
        ActionController::Base.helpers.link_to(
          'Learn More',
          help_page_url(
            'user/project/import/github.md', anchor: 'use-a-github-personal-access-token'
          ),
          target: '_blank',
          rel: 'noopener noreferrer'
        )
      end

      it "handles the error" do
        get :status, format: :json

        expect(session[:"#{provider}_access_token"]).to be_nil
        expect(controller).to redirect_to(new_import_url)
        expect(flash[:alert]).to eq("Your GitHub personal access token does not have the required scope to import. " \
                                    "#{docs_link}.")
      end
    end

    context 'when user has few different repos' do
      let(:repo_struct) { Struct.new(:id, :login, :full_name, :name, :owner, keyword_init: true) }
      let(:provider_repos) do
        [repo_struct.new(login: 'vim', full_name: 'asd/vim', name: 'vim', owner: { login: 'owner' })]
      end

      let!(:imported_project) do
        create(
          :project,
          import_type: provider, namespace: user.namespace,
          import_status: :finished, import_source: 'example/repo'
        )
      end

      it 'responds with expected high-level structure' do
        get :status, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.dig("imported_projects", 0, "id")).to eq(imported_project.id)
        expect(json_response.dig("provider_repos", 0, "id")).to eq(provider_repos[0].id)
      end
    end

    it_behaves_like 'calls repos through Clients::Proxy with expected args'

    context 'with namespace_id param' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      after do
        sign_out(user)
      end

      context 'when user is allowed to create projects in this namespace' do
        let(:namespace) { create(:namespace, owner: user) }

        it 'provides namespace to the template' do
          get :status, params: { namespace_id: namespace.id }, format: :html

          expect(response).to have_gitlab_http_status :ok
          expect(assigns(:namespace)).to eq(namespace)
        end
      end

      context 'when user is not allowed to create projects in this namespace' do
        let(:namespace) { create(:namespace) }

        it 'renders 404' do
          get :status, params: { namespace_id: namespace.id }, format: :html

          expect(response).to have_gitlab_http_status :not_found
        end
      end
    end

    context 'pagination' do
      context 'when cursor is specified' do
        let(:pagination_params) { { before: nil, after: 'CURSOR' } }
        let(:params) { pagination_params }

        it_behaves_like 'calls repos through Clients::Proxy with expected args'
      end
    end

    context 'when relation type params present' do
      let(:organization_login) { 'test-login' }
      let(:params) { pagination_params.merge(relation_type: 'organization', organization_login: organization_login) }
      let(:pagination_defaults) { { first: 25 } }

      it_behaves_like 'calls repos through Clients::Proxy with expected args'

      context 'when organization_login is too long and with ":"' do
        let(:organization_login) { ":#{Array.new(270) { ('a'..'z').to_a.sample }.join}" }

        it_behaves_like 'calls repos through Clients::Proxy with expected args'
      end
    end

    context 'when filtering' do
      let(:filter_param) { FFaker::Lorem.word }
      let(:params) { { filter: filter_param } }

      it_behaves_like 'calls repos through Clients::Proxy with expected args'

      context 'with pagination' do
        context 'when before cursor present' do
          let(:pagination_params) { { before: 'before-cursor', after: nil } }
          let(:params) { { filter: filter_param }.merge(pagination_params) }

          it_behaves_like 'calls repos through Clients::Proxy with expected args'
        end

        context 'when after cursor present' do
          let(:pagination_params) { { before: nil, after: 'after-cursor' } }
          let(:params) { { filter: filter_param }.merge(pagination_params) }

          it_behaves_like 'calls repos through Clients::Proxy with expected args'
        end
      end

      context 'when user input contains colons and spaces' do
        let(:filter_param) { ' test1:test2 test3 : test4 ' }

        it_behaves_like 'calls repos through Clients::Proxy with expected args'
      end
    end

    context 'when rate limit threshold is exceeded' do
      before do
        allow(controller).to receive(:status).and_raise(Gitlab::GithubImport::RateLimitError)
      end

      it 'returns 429' do
        get :status, format: :json

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when the GraphQL search response contains a nil node' do
      let(:graphql_response) do
        Sawyer::Resource.new(
          Sawyer::Agent.new(''),
          data: {
            search: {
              nodes: [
                { id: 1, name: 'vim', full_name: 'asd/vim', owner: { login: 'asd' } },
                nil
              ],
              pageInfo: {},
              repositoryCount: 1
            }
          }
        ).to_h
      end

      before do
        allow(client_stub).to receive(:search_repos_by_name_graphql).and_return(graphql_response)
        allow_next_instance_of(Gitlab::GithubImport::Clients::Proxy) do |proxy|
          allow(proxy).to receive(:repos).and_call_original
          allow(proxy).to receive(:client).and_return(client_stub)
        end
      end

      it 'responds with 200 instead of raising Sawyer::Error' do
        get :status, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.dig('provider_repos', 0, 'id')).to eq(1)
      end
    end
  end

  describe "POST create", :clean_gitlab_redis_cache do
    before do
      allow_next_instance_of(Gitlab::GithubImport::ProjectRelationType) do |instance|
        allow(instance).to receive(:for).with("#{provider_username}/vim").and_return('owned')
      end

      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    it_behaves_like 'a GitHub-ish import controller: POST create' do
      context 'when github importer is not enabled' do
        before do
          stub_application_setting(import_sources: [])
        end

        it 'returns 404' do
          post :create, params: { target_namespace: user.namespace }, format: :json

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    it_behaves_like 'project import rate limiter'

    context 'with refresh credentials in the session' do
      let(:refresh_credentials) { { 'refresh_token' => 'ghr_token', 'expires_at' => 1, 'refresh_token_expires_at' => 2 } }

      before do
        assign_session_token(provider)
        session[:github_refresh_credentials] = refresh_credentials
      end

      def expect_service_to_receive_access_params(expected_access_params)
        service = instance_double(Import::GithubService, :request_channel= => nil)
        allow(Import::GithubService).to receive(:new).and_return(service)
        expect(service).to receive(:execute).with(expected_access_params, :github)
          .and_return({ status: :error, http_status: :unprocessable_entity })
      end

      it 'passes them to the service when authenticated with OAuth' do
        session[:github_oauth_token] = true

        expect_service_to_receive_access_params(
          github_access_token: session[:github_access_token],
          refresh_token: 'ghr_token',
          expires_at: 1,
          refresh_token_expires_at: 2
        )

        post :create, params: { target_namespace: user.namespace_path }, format: :json
      end

      it 'does not pass them with a personal access token' do
        expect_service_to_receive_access_params(github_access_token: session[:github_access_token])

        post :create, params: { target_namespace: user.namespace_path }, format: :json
      end

      it 'passes the stored user credential id with OAuth' do
        session[:github_oauth_token] = true
        session[:github_user_credential_id] = non_existing_record_id

        expect_service_to_receive_access_params(
          github_access_token: session[:github_access_token],
          refresh_token: 'ghr_token',
          expires_at: 1,
          refresh_token_expires_at: 2,
          user_credential_id: non_existing_record_id
        )

        post :create, params: { target_namespace: user.namespace_path }, format: :json
      end

      it 'does not pass the stored user credential id with a personal access token' do
        session[:github_user_credential_id] = non_existing_record_id

        expect_service_to_receive_access_params(github_access_token: session[:github_access_token])

        post :create, params: { target_namespace: user.namespace_path }, format: :json
      end
    end

    context 'with the continuous_sync optional stage' do
      let(:optional_stages) { { 'attachments_import' => 'true', 'continuous_sync' => 'true' } }

      before do
        assign_session_token(provider)
      end

      def expect_service_to_receive_optional_stages(expected_stages)
        expect(Import::GithubService).to receive(:new) do |_client, _user, params|
          expect(params[:optional_stages].to_h).to eq(expected_stages)

          instance_double(
            Import::GithubService,
            execute: { status: :error, http_status: :unprocessable_entity },
            :request_channel= => nil
          )
        end
      end

      context 'when authenticated with OAuth' do
        before do
          session[:github_oauth_token] = true
        end

        it 'passes the continuous_sync stage to the service' do
          expect_service_to_receive_optional_stages(optional_stages)

          post :create, params: { target_namespace: user.namespace_path, optional_stages: optional_stages }, format: :json
        end

        context 'when the github_continuous_import feature flag is disabled' do
          before do
            stub_feature_flags(github_continuous_import: false)
          end

          it 'removes the continuous_sync stage' do
            expect_service_to_receive_optional_stages(optional_stages.except('continuous_sync'))

            post :create, params: { target_namespace: user.namespace_path, optional_stages: optional_stages }, format: :json
          end
        end
      end

      context 'when authenticated with a personal access token' do
        it 'removes the continuous_sync stage' do
          expect_service_to_receive_optional_stages(optional_stages.except('continuous_sync'))

          post :create, params: { target_namespace: user.namespace_path, optional_stages: optional_stages }, format: :json
        end
      end
    end
  end

  describe "GET realtime_changes" do
    let(:user) { create(:user) }

    before do
      assign_session_token(provider)
    end

    it_behaves_like 'a GitHub-ish import controller: GET realtime_changes'

    it 'includes stats in response' do
      project = create(:project, import_type: provider, namespace: user.namespace, import_status: :finished, import_source: 'example/repo')

      ::Gitlab::GithubImport::ObjectCounter.increment(project, :issue, :imported, value: 8)

      get :realtime_changes

      expect(json_response[0]).to include('stats')
      expect(json_response[0]['stats']).to include('fetched')
      expect(json_response[0]['stats']).to include('imported')
    end
  end

  describe "GET failures" do
    let_it_be_with_reload(:project) { create(:project, import_type: 'github', import_status: :started, import_source: 'example/repo', import_url: 'https://fake.url') }
    let!(:import_failure) do
      create(:import_failure,
        project: project,
        source: 'Gitlab::GithubImport::Importer::PullRequestImporter',
        external_identifiers: { iid: 2, object_type: 'pull_request', title: 'My Pull Request' }
      )
    end

    let(:user) { project.owner }

    before do
      sign_in(user)
    end

    context 'when import is not finished' do
      it 'return bad_request' do
        get :failures, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('The import is not complete.')
      end
    end

    context 'when import is finished' do
      before do
        project.import_state.finish
      end

      it 'includes failure details in response' do
        get :failures, params: { project_id: project.id }

        expect(json_response[0]['type']).to eq('pull_request')
        expect(json_response[0]['title']).to eq('My Pull Request')
        expect(json_response[0]['provider_url']).to eq("https://fake.url/example/repo/pull/2")
        expect(json_response[0]['details']['source']).to eq(import_failure.source)
      end

      it 'paginates records' do
        issue_title = 'My Issue'

        create(
          :import_failure,
          project: project,
          source: 'Gitlab::GithubImport::Importer::IssueAndLabelLinksImporter',
          external_identifiers: { iid: 3, object_type: 'issue', title: issue_title }
        )

        get :failures, params: { project_id: project.id, page: 2, per_page: 1 }

        expect(json_response.size).to eq(1)
        expect(json_response.first['title']).to eq(issue_title)
      end
    end

    context 'when signed user is not the owner' do
      let(:user) { create(:user) }

      it 'renders 404' do
        get :failures, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe "POST cancel" do
    let_it_be(:project) do
      create(
        :project, :import_started,
        import_type: 'github', import_url: 'https://fake.url', import_source: 'login/repo'
      )
    end

    let(:user) { project.owner }

    before do
      sign_in(user)
    end

    context 'when project import was canceled' do
      before do
        allow(Import::Github::CancelProjectImportService)
          .to receive(:new).with(project, user)
          .and_return(double(execute: { status: :success, project: project }))

        allow_next_instance_of(Gitlab::GithubImport::ProjectRelationType) do |instance|
          allow(instance).to receive(:for).with('login/repo').and_return('owned')
        end
      end

      it 'returns success' do
        post :cancel, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when project import was not canceled' do
      before do
        allow(Import::Github::CancelProjectImportService)
          .to receive(:new).with(project, user)
          .and_return(double(execute: { status: :error, message: 'The import cannot be canceled because it is finished', http_status: :bad_request }))
      end

      it 'returns error' do
        post :cancel, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['errors']).to eq('The import cannot be canceled because it is finished')
      end
    end

    context 'when signed user is not the owner' do
      let(:user) { create(:user) }

      it 'renders 404' do
        post :cancel, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST cancel_all' do
    context 'when import is in progress' do
      it 'returns success' do
        project = create(:project, :import_scheduled, namespace: user.namespace, import_type: 'github', import_url: 'https://fake.url')
        project2 = create(:project, :import_started, namespace: user.namespace, import_type: 'github', import_url: 'https://fake2.url')

        expect(Import::Github::CancelProjectImportService)
          .to receive(:new).with(project, user)
          .and_return(double(execute: { status: :success, project: project }))

        expect(Import::Github::CancelProjectImportService)
          .to receive(:new).with(project2, user)
          .and_return(double(execute: { status: :bad_request, message: 'The import cannot be canceled because it is finished' }))

        post :cancel_all

        expect(json_response).to match_array([
          {
            'id' => project.id,
            'status' => 'success'
          },
          {
            'id' => project2.id,
            'status' => 'bad_request',
            'error' => 'The import cannot be canceled because it is finished'
          }
        ])
      end
    end

    context 'when there is no imports in progress' do
      it 'returns an empty array' do
        create(:project, :import_finished, namespace: user.namespace, import_type: 'github', import_url: 'https://fake.url')

        post :cancel_all

        expect(json_response).to eq([])
      end
    end

    context 'when there is no projects created by user' do
      it 'returns an empty array' do
        other_user_project = create(:project, :import_started, import_type: 'github', import_url: 'https://fake.url')

        post :cancel_all

        expect(json_response).to eq([])
        expect(other_user_project.import_status).to eq('started')
      end
    end
  end

  describe 'GET counts' do
    let(:expected_result) do
      {
        'owned' => 3,
        'collaborated' => 2,
        'organization' => 1
      }
    end

    it 'returns repos count by type' do
      expect_next_instance_of(Gitlab::GithubImport::Clients::Proxy) do |client_proxy|
        expect(client_proxy).to receive(:count_repos_by).with('owned', user.id).and_return(3)
        expect(client_proxy).to receive(:count_repos_by).with('collaborated', user.id).and_return(2)
        expect(client_proxy).to receive(:count_repos_by).with('organization', user.id).and_return(1)
      end

      get :counts

      expect(json_response).to eq(expected_result)
    end
  end
end
