# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Integrations, feature_category: :integrations do # rubocop:disable RSpec/SpecFilePathFormat -- split from integrations_spec.rb by topic
  include Integrations::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, creator_id: user.id, namespace: user.namespace, owners: [user]) }

  context "Project level integrations" do
    let_it_be(:available_integration_names) do
      excluded_integrations = [Integrations::GitlabSlackApplication.to_param, Integrations::Zentao.to_param]
      Integration.available_integration_names(include_instance_specific: false) - excluded_integrations
    end

    let_it_be(:project_integrations_map, freeze: false) do
      available_integration_names.index_with do |name|
        # Activate Confluence so it appears in API response
        traits = (name == 'confluence' ? [] : [:inactive])
        create(integration_factory(name), *traits, project: project)
      end
    end

    %w[integrations services].each do |endpoint|
      describe "GET /projects/:id/#{endpoint}" do
        it 'returns authentication error when unauthenticated' do
          get api("/projects/#{project.id}/#{endpoint}")

          expect(response).to have_gitlab_http_status(:unauthorized)
        end

        it "returns error when authenticated but user is not a project owner" do
          project.add_developer(user2)
          get api("/projects/#{project.id}/#{endpoint}", user2)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it "returns a list of all active integrations" do
          get api("/projects/#{project.id}/#{endpoint}", user)

          aggregate_failures 'expect successful response with all active integrations' do
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_an Array
            expect(json_response.count).to eq(1)
            expect(json_response.first['slug']).to eq('confluence')
            expect(response).to match_response_schema('public_api/v4/integrations')
          end
        end

        context 'when a project and group share the same numeric id' do
          include_context 'with a project and group that share a numeric id'

          it 'denies a group-scoped granular token', :aggregate_failures do
            pat = granular_token_for(same_id_group, :read_integration)

            get api("/projects/#{same_id}/#{endpoint}", personal_access_token: pat)

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['error']).to eq('insufficient_granular_scope')
          end

          it 'grants a project-scoped granular token' do
            pat = granular_token_for(same_id_project, :read_integration)

            get api("/projects/#{same_id}/#{endpoint}", personal_access_token: pat)

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end

      describe "POST /projects/:id/#{endpoint}/:slug/trigger" do
        describe 'Mattermost integration' do
          let(:integration_name) { 'mattermost_slash_commands' }

          context 'when no integration is available' do
            it 'returns a not found message' do
              post api("/projects/#{project.id}/#{endpoint}/idonotexist/trigger")

              expect(response).to have_gitlab_http_status(:not_found)
              expect(json_response["error"]).to eq("404 Not Found")
            end
          end

          context 'when the integration exists' do
            let(:params) { { token: 'secrettoken' } }

            context 'when the integration is not active' do
              before do
                project_integrations_map[integration_name].deactivate!
              end

              it 'when the integration is inactive' do
                post api("/projects/#{project.id}/#{endpoint}/#{integration_name}/trigger"), params: params

                expect(response).to have_gitlab_http_status(:not_found)
              end
            end

            context 'when the integration is active' do
              before do
                project_integrations_map[integration_name].activate!
              end

              it 'returns status 200' do
                post api("/projects/#{project.id}/#{endpoint}/#{integration_name}/trigger"), params: params

                expect(response).to have_gitlab_http_status(:ok)
              end
            end

            context 'when the project can not be found' do
              it 'returns a generic 404' do
                post api("/projects/404/#{endpoint}/#{integration_name}/trigger"), params: params

                expect(response).to have_gitlab_http_status(:not_found)
                expect(json_response["message"]).to eq("404 Integration Not Found")
              end
            end
          end
        end
      end

      describe 'Mattermost integration' do
        let(:integration_name) { 'mattermost' }
        let(:params) do
          { webhook: 'https://hook.example.com', username: 'username' }
        end

        before do
          project_integrations_map[integration_name].activate!
        end

        it 'accepts a username for update' do
          put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user), params: params.merge(username: 'new_username')

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['properties']['username']).to eq('new_username')
        end
      end

      describe 'Microsoft Teams integration' do
        let_it_be(:group) { create(:group) }
        let(:integration_name) { 'microsoft-teams' }
        let(:params) do
          {
            webhook: 'https://hook.example.com',
            branches_to_be_notified: 'default',
            notify_only_broken_pipelines: false
          }
        end

        before do
          create(:microsoft_teams_integration, group: group, project: nil)
          project.update!(namespace: group)
          project_integrations_map[integration_name.underscore].activate!
        end

        it 'accepts branches_to_be_notified for update' do
          put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user),
            params: params.merge(branches_to_be_notified: 'all')

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['properties']['branches_to_be_notified']).to eq('all')
        end

        it 'accepts notify_only_broken_pipelines for update' do
          put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user),
            params: params.merge(notify_only_broken_pipelines: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['properties']['notify_only_broken_pipelines']).to be(true)
        end

        it 'accepts `use_inherited_settings` for inheritance' do
          expect do
            put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user),
              params: params.merge(use_inherited_settings: true)
          end.to change { project_integrations_map[integration_name.underscore].reload.inherit_from_id }.from(nil)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['inherited']).to be(true)
        end
      end

      describe 'Hangouts Chat integration' do
        let(:integration_name) { 'hangouts-chat' }
        let(:params) do
          {
            webhook: 'https://hook.example.com',
            branches_to_be_notified: 'default'
          }
        end

        before do
          project_integrations_map[integration_name.underscore].activate!
        end

        it 'accepts branches_to_be_notified for update', :aggregate_failures do
          put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user), params: params.merge(branches_to_be_notified: 'all')

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['properties']['branches_to_be_notified']).to eq('all')
        end

        it 'only requires the webhook param' do
          put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user), params: { webhook: 'https://hook.example.com' }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      describe 'Jira integration' do
        let(:integration_name) { 'jira' }
        let(:params) do
          { url: 'https://jira.example.com', username: 'username', password: 'password', jira_auth_type: 0 }
        end

        before do
          project_integrations_map[integration_name].properties = params
          project_integrations_map[integration_name].activate!
        end

        it 'returns the jira_issue_transition_id for get request' do
          get api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['properties']).to include('jira_issue_transition_id' => '56-1')
        end

        it 'returns the jira_issue_transition_id for put request' do
          put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user), params: params.merge(jira_issue_transition_id: '1')

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['properties']['jira_issue_transition_id']).to eq('1')
        end
      end

      describe 'Pipelines Email Integration' do
        let(:integration_name) { 'pipelines-email' }

        describe 'branch selection validation' do
          using RSpec::Parameterized::TableSyntax

          where(:selection, :status) do
            'all'                   | :ok
            'default'               | :ok
            'protected'             | :ok
            'default_and_protected' | :ok
            ' default '             | :ok
            'other'                 | :bad_request
            'default,protected'     | :bad_request
            'default, protected'    | :bad_request
            'bogus'                 | :bad_request
            ''                      | :bad_request
          end

          with_them do
            it 'validates selections through the REST API' do
              put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user),
                params: { recipients: 'test@example.com', branches_to_be_notified: selection }

              expect(response).to have_gitlab_http_status(status)
            end
          end

          it 'persists a normalized selection', :aggregate_failures do
            put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user),
              params: { recipients: 'test@example.com', branches_to_be_notified: ' default_and_protected ' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['properties']['branches_to_be_notified']).to eq('default_and_protected')
          end

          it 'retains the default selection when the field is omitted', :aggregate_failures do
            put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user),
              params: { recipients: 'test@example.com' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['properties']['branches_to_be_notified']).to eq('default')
          end
        end

        context 'notify_only_broken_pipelines property was saved as a string' do
          before do
            project_integrations_map[integration_name.underscore].activate!
          end

          it 'returns boolean values for notify_only_broken_pipelines' do
            get api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user)

            expect(json_response['properties']['notify_only_broken_pipelines']).to be(true)
          end
        end
      end

      describe 'GitLab for Slack app integration' do
        before do
          stub_application_setting(slack_app_enabled: true)
          create(:gitlab_slack_application_integration, project: project)
        end

        describe "PUT /projects/:id/#{endpoint}/gitlab-slack-application" do
          context 'for integration creation' do
            before do
              project.gitlab_slack_application_integration.destroy!
            end

            it 'returns 422' do
              put api("/projects/#{project.id}/#{endpoint}/gitlab-slack-application", user)

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
              expect(json_response['message']).to eq('You cannot create the GitLab for Slack app integration from the API')
            end
          end

          context 'for integration update' do
            before do
              project.gitlab_slack_application_integration.update!(active: false)
            end

            it "does not enable the integration" do
              put api("/projects/#{project.id}/#{endpoint}/gitlab-slack-application", user)

              expect(response).to have_gitlab_http_status(:ok)
              expect(project.gitlab_slack_application_integration.reload).to have_attributes(active: false)
            end
          end
        end

        describe "GET /projects/:id/#{endpoint}/gitlab-slack-application" do
          it "fetches the integration and returns the correct fields" do
            get api("/projects/#{project.id}/#{endpoint}/gitlab-slack-application", user)

            expect(response).to have_gitlab_http_status(:ok)
            assert_correct_response_fields(json_response['properties'].keys, project.gitlab_slack_application_integration)
          end
        end

        describe "DELETE /projects/:id/#{endpoint}/gitlab-slack-application" do
          it "disables the integration" do
            expect { delete api("/projects/#{project.id}/#{endpoint}/gitlab-slack-application", user) }
              .to change { project.gitlab_slack_application_integration.reload.activated? }.from(true).to(false)

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end
      end

      describe 'GitLab for Jira Cloud app integration' do
        before do
          stub_application_setting(jira_connect_application_key: 'mock_key')
          create(:jira_cloud_app_integration, project: project)
        end

        describe "PUT /projects/:id/#{endpoint}/jira-cloud-app" do
          context 'for integration creation' do
            before do
              project.jira_cloud_app_integration.destroy!
            end

            it 'returns 422' do
              put api("/projects/#{project.id}/#{endpoint}/jira-cloud-app", user)

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
              expect(json_response['message']).to eq('You cannot create the GitLab for Jira Cloud app integration from the API')
            end
          end

          context 'for integration update' do
            before do
              project.jira_cloud_app_integration.update!(active: false)
            end

            it "does not enable the integration" do
              put api("/projects/#{project.id}/#{endpoint}/jira-cloud-app", user)

              expect(response).to have_gitlab_http_status(:ok)
              expect(project.jira_cloud_app_integration.reload).to have_attributes(active: false)
            end
          end
        end

        describe "GET /projects/:id/#{endpoint}/jira-cloud-app" do
          it "fetches the integration and returns the correct fields" do
            get api("/projects/#{project.id}/#{endpoint}/jira-cloud-app", user)

            expect(response).to have_gitlab_http_status(:ok)
            assert_correct_response_fields(json_response['properties'].keys, project.jira_cloud_app_integration)
          end
        end

        describe "DELETE /projects/:id/#{endpoint}/jira-cloud-app" do
          it "does not disable the integration" do
            expect { delete api("/projects/#{project.id}/#{endpoint}/jira-cloud-app", user) }
              .not_to change { project.jira_cloud_app_integration.reload.activated? }.from(true)

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to eq('You cannot disable the GitLab for Jira Cloud app integration from the API')
          end
        end
      end

      private

      def assert_correct_response_fields(response_keys, integration)
        assert_fields_match_integration(response_keys, integration)
        assert_secret_fields_filtered(response_keys, integration)
      end

      def assert_fields_match_integration(response_keys, integration)
        expect(response_keys).to match_array(integration.api_field_names)
      end

      def assert_secret_fields_filtered(response_keys, integration)
        expect(response_keys).not_to include(*integration.secret_fields) unless integration.secret_fields.empty?
      end
    end

    describe 'granular token authorization' do
      let(:boundary_object) { project }

      # The `integrations` and backwards-compatible `services` paths share the same code.
      %w[integrations services].each do |endpoint|
        it_behaves_like 'authorizing granular token permissions', :read_integration do
          let(:request) { get api("/projects/#{project.id}/#{endpoint}", personal_access_token: pat) }
        end

        it_behaves_like 'authorizing granular token permissions', :read_integration do
          let(:request) { get api("/projects/#{project.id}/#{endpoint}/mattermost", personal_access_token: pat) }
        end

        it_behaves_like 'authorizing granular token permissions', :delete_integration do
          let(:request) { delete api("/projects/#{project.id}/#{endpoint}/mattermost", personal_access_token: pat) }
        end

        it_behaves_like 'authorizing granular token permissions', :update_integration do
          let(:request) do
            put api("/projects/#{project.id}/#{endpoint}/mattermost", personal_access_token: pat),
              params: { webhook: 'https://example.com', username: 'test' }
          end
        end

        context 'when a project and group share the same numeric id' do
          include_context 'with a project and group that share a numeric id'

          it 'denies a group-scoped token on update', :aggregate_failures do
            pat = granular_token_for(same_id_group, :update_integration)

            put api("/projects/#{same_id}/#{endpoint}/mattermost", personal_access_token: pat),
              params: { webhook: 'https://example.com', username: 'test' }

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['error']).to eq('insufficient_granular_scope')
          end

          it 'denies a group-scoped token on delete', :aggregate_failures do
            pat = granular_token_for(same_id_group, :delete_integration)

            delete api("/projects/#{same_id}/#{endpoint}/mattermost", personal_access_token: pat)

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['error']).to eq('insufficient_granular_scope')
          end
        end
      end
    end
  end

  context 'when the project is archived' do
    let_it_be(:archived_project) { create(:project, :archived, owners: user) }
    let_it_be_with_reload(:integration) { create(:pipelines_email_integration, project: archived_project) }

    it 'allows disabling an integration' do
      delete api("/projects/#{archived_project.id}/integrations/pipelines-email", user)

      expect(response).to have_gitlab_http_status(:no_content)
      expect(integration.reload).not_to be_active
    end

    it 'does not allow a developer to disable an integration' do
      archived_project.add_developer(user2)

      delete api("/projects/#{archived_project.id}/integrations/pipelines-email", user2)

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(integration.reload).to be_active
    end

    it 'does not allow updating an integration' do
      put api("/projects/#{archived_project.id}/integrations/pipelines-email", user),
        params: { recipients: 'other@example.com' }

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'permission checks' do
    def deny_permission(permission)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, permission, project).and_return(false)
    end

    it 'checks read_integration to list integrations' do
      deny_permission(:read_integration)

      get api("/projects/#{project.id}/integrations", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'checks read_integration to read an integration' do
      deny_permission(:read_integration)

      get api("/projects/#{project.id}/integrations/emails-on-push", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'checks read_integration for HEAD requests' do
      deny_permission(:read_integration)

      head api("/projects/#{project.id}/integrations/emails-on-push", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'checks update_integration to set up an integration' do
      deny_permission(:update_integration)

      put api("/projects/#{project.id}/integrations/emails-on-push", user), params: { recipients: 'user@example.com' }

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when the resource is archived' do
      let_it_be(:archived) { create(:project, :archived, owners: [user]) }

      it 'allows reading integrations' do
        get api("/projects/#{archived.id}/integrations", user)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not allow setting up an integration' do
        put api("/projects/#{archived.id}/integrations/emails-on-push", user), params: { recipients: 'user@example.com' }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
