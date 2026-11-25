# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Integrations, feature_category: :integrations do # rubocop:disable RSpec/SpecFilePathFormat -- split from integrations_spec.rb by topic
  include Integrations::TestHelpers

  let_it_be(:user) { create(:user) }
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
      where(:integration) do
        # You cannot create a GitLab for Slack app. You must install the app from the GitLab UI.
        unavailable_integration_names = [
          Integrations::GitlabSlackApplication.to_param,
          Integrations::Zentao.to_param
        ]

        names = Integration.available_integration_names(include_instance_specific: false, include_project_specific: false)
        names.reject { |name| unavailable_integration_names.include?(name) }
      end

      with_them do
        integration = params[:integration]

        describe "PUT /groups/:id/#{endpoint}/#{integration.dasherize}" do
          it_behaves_like 'set up an integration', endpoint: endpoint, integration: integration, parent_resource_name: 'group' do
            let(:parent_resource) { group }
            let(:integrations_map) { group_integrations_map }
          end
        end

        describe "DELETE /groups/:id/#{endpoint}/#{integration.dasherize}" do
          it_behaves_like 'disable an integration', endpoint: endpoint, integration: integration, parent_resource_name: 'group' do
            let(:parent_resource) { group }
            let(:integrations_map) { group_integrations_map }
          end
        end
      end
    end
  end
end
