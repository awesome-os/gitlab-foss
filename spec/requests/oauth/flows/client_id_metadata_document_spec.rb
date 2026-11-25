# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'OAuth Authorization Code Flow with a Client ID Metadata Document client_id',
  feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, :with_namespace, organizations: [organization]) }
  let_it_be(:cimd_url) { 'https://client.example.com/oauth/client.json' }
  let_it_be(:application) do
    create(:oauth_application, organization: organization, cimd_url: cimd_url, confidential: false,
      redirect_uri: 'http://localhost:8080/callback', scopes: 'mcp')
  end

  let(:client_id) { cimd_url }
  let(:code_verifier) { SecureRandom.urlsafe_base64(64) }
  let(:code_challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false) }

  let(:authorization_params) do
    {
      client_id: client_id,
      response_type: 'code',
      redirect_uri: application.redirect_uri,
      scope: 'mcp',
      code_challenge: code_challenge,
      code_challenge_method: 'S256',
      state: 'abcd'
    }
  end

  before do
    sign_in(user)
  end

  def authorization_code
    post '/oauth/authorize', params: authorization_params
    Addressable::URI.parse(response.location).query_values['code']
  end

  def authorization_code_with_uid
    post '/oauth/authorize', params: authorization_params.merge(client_id: application.uid)
    Addressable::URI.parse(response.location).query_values['code']
  end

  def exchange(code, **overrides)
    post '/oauth/token', params: {
      client_id: cimd_url,
      grant_type: 'authorization_code',
      redirect_uri: application.redirect_uri,
      code: code,
      code_verifier: code_verifier
    }.merge(overrides)
  end

  it 'renders the consent screen for the application registered for the URL' do
    get '/oauth/authorize', params: authorization_params

    expect(response).to have_gitlab_http_status(:ok)
    expect(response.body).to include(application.name)
  end

  it 'issues an access token for the application', :aggregate_failures do
    exchange(authorization_code)

    expect(response).to have_gitlab_http_status(:ok)
    expect(OauthAccessToken.by_token(json_response['access_token']).application).to eq(application)
  end

  it 'refreshes the access token using the URL as client_id' do
    exchange(authorization_code)

    post '/oauth/token', params: {
      client_id: cimd_url, grant_type: 'refresh_token', refresh_token: json_response['refresh_token']
    }

    expect(response).to have_gitlab_http_status(:ok)
  end

  it 'revokes the access token using the URL as client_id', :aggregate_failures do
    exchange(authorization_code)
    access_token = json_response['access_token']

    post '/oauth/revoke', params: { client_id: cimd_url, token: access_token }

    expect(response).to have_gitlab_http_status(:ok)
    expect(OauthAccessToken.by_token(access_token)).to be_revoked
  end

  it 'does not revoke the access token using another application URL as client_id', :aggregate_failures do
    create(:oauth_application, organization: organization, cimd_url: 'https://other.example.com/client.json',
      confidential: false, redirect_uri: application.redirect_uri, scopes: 'mcp')
    exchange(authorization_code)
    access_token = json_response['access_token']

    post '/oauth/revoke', params: { client_id: 'https://other.example.com/client.json', token: access_token }

    expect(response).to have_gitlab_http_status(:forbidden)
    expect(OauthAccessToken.by_token(access_token)).not_to be_revoked
  end

  it 'limits the token to the mcp scope when another scope is requested' do
    post '/oauth/authorize', params: authorization_params.merge(scope: 'api')
    exchange(Addressable::URI.parse(response.location).query_values['code'])

    expect(json_response['scope']).to eq('mcp')
  end

  it 'requires PKCE on authorization' do
    get '/oauth/authorize', params: authorization_params.except(:code_challenge, :code_challenge_method)

    expect(response.body)
      .to include('PKCE code_challenge is required for OAuth applications that use a Client ID Metadata Document.')
  end

  it 'requires PKCE on token exchange', :aggregate_failures do
    exchange(authorization_code, code_verifier: nil)

    expect(response).to have_gitlab_http_status(:bad_request)
    expect(json_response['error_description'])
      .to eq('PKCE code_verifier is required for OAuth applications that use a Client ID Metadata Document')
  end

  it 'rejects a code exchanged with another application URL as client_id', :aggregate_failures do
    create(:oauth_application, organization: organization, cimd_url: 'https://other.example.com/client.json',
      confidential: false, redirect_uri: application.redirect_uri, scopes: 'mcp')

    exchange(authorization_code, client_id: 'https://other.example.com/client.json')

    expect(response).to have_gitlab_http_status(:unauthorized)
    expect(json_response['error']).to eq('invalid_client')
  end

  it 'rejects an unknown code exchanged with the URL as client_id', :aggregate_failures do
    exchange('unknown-code')

    expect(response).to have_gitlab_http_status(:unauthorized)
    expect(json_response['error']).to eq('invalid_client')
  end

  context 'when the URL is registered in another organization' do
    let(:client_id) { 'https://elsewhere.example.com/client.json' }

    before_all do
      create(:oauth_application, cimd_url: 'https://elsewhere.example.com/client.json', confidential: false,
        redirect_uri: 'http://localhost:8080/callback', scopes: 'mcp')
    end

    it 'does not resolve the client' do
      get '/oauth/authorize', params: authorization_params

      expect(response.body).to include('Client authentication failed due to unknown client')
    end
  end

  context 'when the client_id uses http' do
    let(:client_id) { 'http://client.example.com/oauth/client.json' }

    it 'does not resolve the URL on authorization' do
      get '/oauth/authorize', params: authorization_params

      expect(response.body).to include('Client authentication failed due to unknown client')
    end

    it 'does not resolve the URL on token exchange', :aggregate_failures do
      exchange(authorization_code_with_uid, client_id: client_id)

      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(json_response['error']).to eq('invalid_client')
    end
  end

  context 'when dynamic client registration is disabled' do
    before do
      stub_application_setting(dynamic_client_registration_enabled: false)
    end

    it 'still issues an access token' do
      exchange(authorization_code)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  context 'when the oauth_client_id_metadata_documents feature flag is disabled' do
    before do
      stub_feature_flags(oauth_client_id_metadata_documents: false)
    end

    it 'does not resolve the URL on authorization' do
      get '/oauth/authorize', params: authorization_params

      expect(response.body).to include('Client authentication failed due to unknown client')
    end

    it 'does not resolve the URL on token exchange', :aggregate_failures do
      code = authorization_code_with_uid

      exchange(code)

      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(json_response['error']).to eq('invalid_client')
    end
  end
end
