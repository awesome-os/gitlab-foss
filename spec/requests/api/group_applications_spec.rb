# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupApplications, :aggregate_failures, feature_category: :system_access do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }
  let_it_be(:non_member) { create(:user) }

  let_it_be(:other_group) { create(:group, :private) }
  let_it_be(:other_group_application) { create(:oauth_application, :group_owned, owner: other_group) }
  let_it_be(:user_owned_application) { create(:oauth_application, owner: owner) }

  let_it_be_with_reload(:application) { create(:oauth_application, :group_owned, owner: group) }

  let_it_be(:public_group) { create(:group, :public) }
  let_it_be(:public_group_application) { create(:oauth_application, :group_owned, owner: public_group) }

  describe 'GET /groups/:id/applications' do
    it_behaves_like 'authorizing granular token permissions', :read_oauth_application do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) { get api("/groups/#{group.id}/applications", personal_access_token: pat) }
    end

    it 'returns the group applications for an owner' do
      get api("/groups/#{group.id}/applications", owner)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.map { |app| app['id'] }).to contain_exactly(application.id)
    end

    it 'returns 403 for a maintainer' do
      get api("/groups/#{group.id}/applications", maintainer)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns 403 for a developer' do
      get api("/groups/#{group.id}/applications", developer)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns 403 for a guest' do
      get api("/groups/#{group.id}/applications", guest)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns 404 for a non-member on a private group' do
      get api("/groups/#{group.id}/applications", non_member)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 401 for an unauthenticated user' do
      get api("/groups/#{group.id}/applications")

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  describe 'GET /groups/:id/applications/:application_id' do
    it_behaves_like 'authorizing granular token permissions', :read_oauth_application do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) do
        get api("/groups/#{group.id}/applications/#{application.id}", personal_access_token: pat)
      end
    end

    it 'returns the application for an owner' do
      get api("/groups/#{group.id}/applications/#{application.id}", owner)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(application.id)
      expect(json_response['application_name']).to eq(application.name)
      expect(json_response).not_to have_key('secret')
    end

    it 'returns 404 for an application owned by another group' do
      get api("/groups/#{group.id}/applications/#{other_group_application.id}", owner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 404 for a user-owned application' do
      get api("/groups/#{group.id}/applications/#{user_owned_application.id}", owner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 404 for a non-member on a private group' do
      get api("/groups/#{group.id}/applications/#{application.id}", non_member)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 403 for a maintainer' do
      get api("/groups/#{group.id}/applications/#{application.id}", maintainer)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns 403 for a non-member on a public group without revealing which applications it owns' do
      [public_group_application, other_group_application].each do |app|
        get api("/groups/#{public_group.id}/applications/#{app.id}", non_member)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it 'returns 401 for an unauthenticated user' do
      get api("/groups/#{group.id}/applications/#{application.id}")

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  describe 'POST /groups/:id/applications' do
    let(:create_params) do
      {
        name: 'test_app',
        redirect_uri: 'https://example.com/callback',
        scopes: 'api',
        confidential: false
      }
    end

    it_behaves_like 'authorizing granular token permissions', :create_oauth_application,
      expected_success_status: :created do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) do
        post api("/groups/#{group.id}/applications", personal_access_token: pat), params: create_params
      end
    end

    it 'creates a new application owned by the group' do
      expect do
        post api("/groups/#{group.id}/applications", owner), params: create_params
      end.to change { Authn::OauthApplication.count }.by(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['application_name']).to eq('test_app')
      expect(json_response['callback_url']).to eq('https://example.com/callback')
      expect(json_response['confidential']).to be(false)
      expect(json_response['secret']).to be_present # the secret is only returned on creation
      expect(json_response['application_id']).to be_present

      app = Authn::OauthApplication.last
      expect(app.owner).to eq(group)
      expect(app.organization).to eq(group.organization)
    end

    it 'returns validation errors' do
      post api("/groups/#{group.id}/applications", owner), params: create_params.merge(redirect_uri: 'invalid url')

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['redirect_uri']).to be_present
    end

    it 'returns 403 for a maintainer' do
      post api("/groups/#{group.id}/applications", maintainer), params: create_params

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns 404 for a non-member on a private group' do
      post api("/groups/#{group.id}/applications", non_member), params: create_params

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 401 for an unauthenticated user' do
      expect do
        post api("/groups/#{group.id}/applications"), params: create_params
      end.not_to change { Authn::OauthApplication.count }

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  describe 'PUT /groups/:id/applications/:application_id' do
    it_behaves_like 'authorizing granular token permissions', :update_oauth_application do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) do
        put api("/groups/#{group.id}/applications/#{application.id}", personal_access_token: pat), params: {
          name: 'updated_app'
        }
      end
    end

    it 'updates the application for an owner' do
      put api("/groups/#{group.id}/applications/#{application.id}", owner), params: {
        name: 'updated_app'
      }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['application_name']).to eq('updated_app')

      expect(application.reload.name).to eq('updated_app')
    end

    it 'does not update the redirect URI or confidential flag' do
      original_redirect_uri = application.redirect_uri

      put api("/groups/#{group.id}/applications/#{application.id}", owner), params: {
        name: 'updated_app',
        redirect_uri: 'https://attacker.example.com/callback',
        confidential: false
      }

      expect(response).to have_gitlab_http_status(:ok)

      expect(application.reload.redirect_uri).to eq(original_redirect_uri)
      expect(application.confidential).to be(true)
    end

    it 'returns validation errors on invalid update' do
      put api("/groups/#{group.id}/applications/#{application.id}", owner), params: {
        name: ''
      }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['name']).to be_present
    end

    it 'returns 404 for an application owned by another group' do
      put api("/groups/#{group.id}/applications/#{other_group_application.id}", owner), params: {
        name: 'updated_app'
      }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(other_group_application.reload.name).not_to eq('updated_app')
    end

    it 'returns 403 for a maintainer' do
      put api("/groups/#{group.id}/applications/#{application.id}", maintainer), params: {
        name: 'updated_app'
      }

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(application.reload.name).not_to eq('updated_app')
    end

    it 'returns 403 for a non-member on a public group without revealing which applications it owns' do
      [public_group_application, other_group_application].each do |app|
        put api("/groups/#{public_group.id}/applications/#{app.id}", non_member), params: { name: 'updated_app' }

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      expect(public_group_application.reload.name).not_to eq('updated_app')
    end

    it 'returns 401 for an unauthenticated user' do
      put api("/groups/#{group.id}/applications/#{application.id}"), params: {
        name: 'updated_app'
      }

      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(application.reload.name).not_to eq('updated_app')
    end
  end

  describe 'DELETE /groups/:id/applications/:application_id' do
    let(:app_to_delete) { create(:oauth_application, :group_owned, owner: group) }

    it_behaves_like 'authorizing granular token permissions', :delete_oauth_application,
      expected_success_status: :no_content do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) do
        delete api("/groups/#{group.id}/applications/#{app_to_delete.id}", personal_access_token: pat)
      end
    end

    it 'deletes the application for an owner' do
      delete api("/groups/#{group.id}/applications/#{app_to_delete.id}", owner)

      expect(response).to have_gitlab_http_status(:no_content)
      expect(Authn::OauthApplication.find_by(id: app_to_delete.id)).to be_nil
    end

    it 'returns 400 when the application cannot be deleted' do
      allow_next_instance_of(Authn::Applications::DestroyService) do |service|
        allow(service).to receive(:execute) do
          app_to_delete.tap { |app| app.errors.add(:base, 'Cannot delete application') }
        end
      end

      delete api("/groups/#{group.id}/applications/#{app_to_delete.id}", owner)

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['base']).to contain_exactly('Cannot delete application')
      expect(Authn::OauthApplication.find_by(id: app_to_delete.id)).not_to be_nil
    end

    it 'returns 404 for an application owned by another group' do
      delete api("/groups/#{group.id}/applications/#{other_group_application.id}", owner)

      expect(response).to have_gitlab_http_status(:not_found)
      expect(Authn::OauthApplication.find_by(id: other_group_application.id)).not_to be_nil
    end

    it 'returns 403 for a maintainer' do
      delete api("/groups/#{group.id}/applications/#{app_to_delete.id}", maintainer)

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(Authn::OauthApplication.find_by(id: app_to_delete.id)).not_to be_nil
    end

    it 'returns 403 for a non-member on a public group without revealing which applications it owns' do
      [public_group_application, other_group_application].each do |app|
        delete api("/groups/#{public_group.id}/applications/#{app.id}", non_member)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      expect(Authn::OauthApplication.find_by(id: public_group_application.id)).not_to be_nil
    end

    it 'returns 401 for an unauthenticated user' do
      delete api("/groups/#{group.id}/applications/#{app_to_delete.id}")

      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(Authn::OauthApplication.find_by(id: app_to_delete.id)).not_to be_nil
    end
  end
end
