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

    where(:integration) do
      # The integrations API supports all project integrations.
      # You cannot create a GitLab for Slack app. You must install the app from the GitLab UI.
      unavailable_integration_names = [
        Integrations::GitlabSlackApplication.to_param,
        Integrations::JiraCloudApp.to_param,
        Integrations::Zentao.to_param
      ]

      names = Integration.available_integration_names(include_instance_specific: false)
      names.reject { |name| unavailable_integration_names.include?(name) }
    end

    # Only on `integrations`: API::Integrations mounts the same IntegratableOperations for `services`,
    # varying just the route prefix. The `services` path stays covered by the per-endpoint examples
    # in project_integrations_spec.rb.
    with_them do
      integration = params[:integration]

      describe "GET /projects/:id/integrations/#{integration.dasherize}" do
        it_behaves_like 'get an integration settings', endpoint: 'integrations', integration: integration, parent_resource_name: 'project' do
          let(:parent_resource) { project }
          let(:integrations_map) { project_integrations_map }
        end
      end
    end
  end
end
