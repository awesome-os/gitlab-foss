# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Integrations, feature_category: :integrations do # rubocop:disable RSpec/SpecFilePathFormat -- split from integrations_spec.rb by topic
  include Integrations::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, owners: user) }

  context "Group level integrations" do
    let_it_be(:available_integration_names) do
      excluded_integrations = [Integrations::GitlabSlackApplication.to_param, Integrations::Zentao.to_param]
      Integration.available_integration_names(include_project_specific: false, include_instance_specific: false) - excluded_integrations
    end

    let_it_be(:group_integrations_map, freeze: false) do
      available_integration_names.index_with do |name|
        traits = (name == 'confluence' ? [] : [:inactive])
        create(integration_factory(name), *traits, :group, group: group)
      end
    end

    'integrations'.tap do |endpoint|
      describe "GET /groups/:id/#{endpoint}" do
        let_it_be(:project_only_integration) { Integration::PROJECT_LEVEL_ONLY_INTEGRATION_NAMES }

        it 'returns authentication error when unauthenticated' do
          get api("/groups/#{group.id}/#{endpoint}")

          expect(response).to have_gitlab_http_status(:unauthorized)
        end

        it "returns error when authenticated but user is not a group owner" do
          group.add_developer(user2)
          get api("/groups/#{group.id}/#{endpoint}", user2)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it "returns a list of all active integrations" do
          get api("/groups/#{group.id}/#{endpoint}", user)

          aggregate_failures 'expect successful response with all active integrations' do
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_an Array
            expect(json_response.count).to eq(1)
            expect(json_response.first['slug']).to eq('confluence')
            expect(response).to match_response_schema('public_api/v4/integrations')
          end
        end

        context 'when an active integration is not available for the group' do
          before do
            allow(Integrations::Confluence).to receive(:available_for_group?).and_return(false)
          end

          it 'does not list the integration', :aggregate_failures do
            get api("/groups/#{group.id}/#{endpoint}", user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_empty
          end
        end

        Integration::PROJECT_LEVEL_ONLY_INTEGRATION_NAMES.map(&:dasherize).each do |integration_name|
          it "returns 400 when trying to access a project-only integration" do
            get api("/groups/#{group.id}/integrations/#{integration_name}", user)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response["message"]).to eq("400 Integration not available")
          end
        end

        context 'when a project and group share the same numeric id' do
          include_context 'with a project and group that share a numeric id'

          it 'denies a project-scoped granular token', :aggregate_failures do
            pat = granular_token_for(same_id_project, :read_integration)

            get api("/groups/#{same_id}/#{endpoint}", personal_access_token: pat)

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['error']).to eq('insufficient_granular_scope')
          end

          it 'grants a group-scoped granular token' do
            pat = granular_token_for(same_id_group, :read_integration)

            get api("/groups/#{same_id}/#{endpoint}", personal_access_token: pat)

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end

    describe 'granular token authorization' do
      let(:boundary_object) { group }

      it_behaves_like 'authorizing granular token permissions', :read_integration do
        let(:request) { get api("/groups/#{group.id}/integrations", personal_access_token: pat) }
      end

      it_behaves_like 'authorizing granular token permissions', :read_integration do
        let(:request) { get api("/groups/#{group.id}/integrations/mattermost", personal_access_token: pat) }
      end

      it_behaves_like 'authorizing granular token permissions', :update_integration do
        let(:request) do
          put api("/groups/#{group.id}/integrations/mattermost", personal_access_token: pat),
            params: { webhook: 'https://example.com', username: 'test' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :delete_integration do
        let(:request) { delete api("/groups/#{group.id}/integrations/mattermost", personal_access_token: pat) }
      end

      context 'when a project and group share the same numeric id' do
        include_context 'with a project and group that share a numeric id'

        it 'denies a project-scoped token on update', :aggregate_failures do
          pat = granular_token_for(same_id_project, :update_integration)

          put api("/groups/#{same_id}/integrations/mattermost", personal_access_token: pat),
            params: { webhook: 'https://example.com', username: 'test' }

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('insufficient_granular_scope')
        end

        it 'denies a project-scoped token on delete', :aggregate_failures do
          pat = granular_token_for(same_id_project, :delete_integration)

          delete api("/groups/#{same_id}/integrations/mattermost", personal_access_token: pat)

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('insufficient_granular_scope')
        end
      end
    end
  end

  context 'when the group is archived' do
    let_it_be(:archived_group) { create(:group, :archived, owners: user) }
    let_it_be_with_reload(:group_integration) { create(:jira_integration, :group, group: archived_group) }

    it 'allows disabling an integration' do
      delete api("/groups/#{archived_group.id}/integrations/jira", user)

      expect(response).to have_gitlab_http_status(:no_content)
      expect(group_integration.reload).not_to be_active
    end

    it 'does not allow a maintainer to disable an integration' do
      archived_group.add_maintainer(user2)

      delete api("/groups/#{archived_group.id}/integrations/jira", user2)

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(group_integration.reload).to be_active
    end

    it 'does not allow updating an integration' do
      put api("/groups/#{archived_group.id}/integrations/jira", user), params: { url: 'https://jira.example.com' }

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'permission checks' do
    def deny_permission(permission)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, permission, group).and_return(false)
    end

    it 'checks read_integration to list integrations' do
      deny_permission(:read_integration)

      get api("/groups/#{group.id}/integrations", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'checks read_integration to read an integration' do
      deny_permission(:read_integration)

      get api("/groups/#{group.id}/integrations/emails-on-push", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'checks read_integration for HEAD requests' do
      deny_permission(:read_integration)

      head api("/groups/#{group.id}/integrations/emails-on-push", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'checks update_integration to set up an integration' do
      deny_permission(:update_integration)

      put api("/groups/#{group.id}/integrations/emails-on-push", user), params: { recipients: 'user@example.com' }

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when the resource is archived' do
      let_it_be(:archived) { create(:group, :archived, owners: [user]) }

      it 'allows reading integrations' do
        get api("/groups/#{archived.id}/integrations", user)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not allow setting up an integration' do
        put api("/groups/#{archived.id}/integrations/emails-on-push", user), params: { recipients: 'user@example.com' }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
