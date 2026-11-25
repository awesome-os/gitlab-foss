# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::GithubGroupsController, feature_category: :importers do
  describe 'GET status' do
    subject(:status) { get '/import/github_group/status', params: params, headers: headers }

    let_it_be(:user) { create(:user) }
    let(:headers) { { 'Accept' => 'application/json' } }
    let(:params) { {} }

    before do
      stub_application_setting(import_sources: ['github'])

      login_as(user)
    end

    context 'when OAuth config is missing' do
      before do
        allow(Gitlab::Auth::OAuth::Provider).to receive(:config_for).with('github').and_return(nil)
      end

      it 'returns missing config error' do
        status

        expect(json_response['errors']).to eq('Missing OAuth configuration for GitHub.')
      end
    end

    context 'when no access token is in the session' do
      it 'redirects to GitHub without forcing the account picker' do
        status

        expect(response).to have_gitlab_http_status(:redirect)
        expect(response.location).to include('/login/oauth/authorize')
        expect(response.location).not_to include('prompt=')
      end
    end

    context 'when a stored GitHub credential was reused' do
      let(:access_token) { 'ghu_stored' }
      let(:organizations_url) { 'https://api.github.com/user/orgs?page=1&per_page=25' }
      let(:organizations) { [{ id: 1, login: 'gitHub-organization', description: 'GitHub Organization' }] }
      let!(:credential) do
        create(:import_user_credential, user: user, provider_account_xid: 583231, access_token: access_token,
          scopes: 'repo,read:org')
      end

      before do
        stub_feature_flags(github_import_reuse_user_credential: true)
        stub_request(:get, 'https://api.github.com/user')
          .with(headers: { 'Authorization' => "token #{access_token}" })
          .to_return(status: 200, body: { id: 583231, login: 'octocat' }.to_json,
            headers: { 'Content-Type' => 'application/json' })
        stub_request(:get, organizations_url)
          .with(headers: { 'Authorization' => "token #{access_token}" })
          .to_return(status: 200, body: organizations.to_json, headers: { 'Content-Type' => 'application/json' })
        # The GitHub import reuses the credential and keeps only its ID in the session
        get '/import/github/new'
      end

      it 'returns the organizations with the stored token' do
        status

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['provider_groups'].pluck('name')).to eq(['gitHub-organization'])
      end

      context 'when the session holds the ID of another user credential' do
        let(:other_user) { create(:user) }

        it 'does not use that token and redirects to GitHub' do
          login_as(other_user)

          status

          expect(response.location).to include('/login/oauth/authorize')
          expect(a_request(:get, organizations_url)).not_to have_been_made
        end
      end
    end

    context 'when OAuth config present' do
      let(:github_access_token) { 'asdasd12345' }

      before do
        post '/import/github/personal_access_token', params: { personal_access_token: github_access_token }
      end

      it 'fetches organizations' do
        organizations = [
          {
            id: 1,
            login: "gitHub-organization",
            description: 'GitHub Organization'
          }
        ]
        stub_request(:get, "https://api.github.com/user/orgs?page=1&per_page=25")
         .to_return(status: 200, body: organizations.to_json, headers: { 'Content-Type' => 'application/json' })

        status

        expect(json_response).to eq({
          "provider_groups" => [
            {
              "name" => "gitHub-organization",
              "description" => "GitHub Organization"
            }
          ]
        })
      end

      context 'with pagination' do
        context 'when no page is specified' do
          it 'requests first page' do
            expect_next_instance_of(Octokit::Client) do |client|
              expect(client).to receive(:organizations).with(nil, { page: 1, per_page: 25 }).and_return([].to_enum)
            end

            status
          end
        end

        context 'when page is specified' do
          let(:params) { { page: 2 } }

          it 'responds with organizations with specified page' do
            expect_next_instance_of(Octokit::Client) do |client|
              expect(client).to receive(:organizations).with(nil, { page: 2, per_page: 25 }).and_return([].to_enum)
            end

            status
          end
        end
      end
    end
  end
end
