# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.sastCiConfiguration', feature_category: :static_application_security_testing do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }

  let(:fields) { 'global { nodes { field } }' }
  let(:query) { graphql_query_for(:project, { full_path: project.full_path }, "id sastCiConfiguration { #{fields} }") }

  context 'when authenticating with a granular personal access token' do
    let(:user) { developer }
    let(:boundary_object) { project }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_project, :read_security_configuration]

    it_behaves_like 'denying a granular token that only authorizes the parent of a field',
      [:read_project, :read_code, :read_security_setting] do
      let(:parent_data_path) { %i[project] }
      let(:field_data_path) { %i[project sast_ci_configuration] }
    end

    context 'when querying the SastCiConfiguration type' do
      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_security_configuration] do
        let(:fields) { '__typename' }
        let(:skipped_data_path) { %i[project sast_ci_configuration __typename] }
      end
    end

    context 'when querying the SastCiConfigurationEntity type' do
      %i[global pipeline].each do |entities_field|
        context "with #{entities_field}" do
          it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
            [:read_project, :read_security_configuration] do
            let(:fields) { "#{entities_field} { nodes { field } }" }
            let(:skipped_data_path) { [:project, :sast_ci_configuration, entities_field, :nodes, 0, :field] }
          end
        end
      end

      context 'with variables' do
        it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
          [:read_project, :read_security_configuration] do
          let(:fields) { 'analyzers { nodes { variables { nodes { field } } } }' }
          let(:skipped_data_path) do
            [:project, :sast_ci_configuration, :analyzers, :nodes, 0, :variables, :nodes, 0, :field]
          end
        end
      end
    end

    context 'when querying the SastCiConfigurationAnalyzersEntity type' do
      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_security_configuration] do
        let(:fields) { 'analyzers { nodes { name } }' }
        let(:skipped_data_path) { [:project, :sast_ci_configuration, :analyzers, :nodes, 0, :name] }
      end
    end

    context 'when querying the SastCiConfigurationOptionsEntity type' do
      before do
        allow_next_instance_of(::Security::CiConfiguration::SastParserService) do |service|
          allow(service).to receive(:configuration).and_return(
            { global: [{ field: 'SAST_EXAMPLE', options: [{ label: 'Example', value: 'example' }] }],
              pipeline: [], analyzers: [] }.with_indifferent_access
          )
        end
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_security_configuration] do
        let(:fields) { 'global { nodes { options { nodes { value } } } }' }
        let(:skipped_data_path) do
          [:project, :sast_ci_configuration, :global, :nodes, 0, :options, :nodes, 0, :value]
        end
      end
    end
  end

  context 'when authenticating as a user' do
    let(:current_user) { developer }

    subject(:entity_field) do
      post_graphql(query, current_user: current_user)

      graphql_data_at(:project, :sast_ci_configuration, :global, :nodes, 0, :field)
    end

    it { is_expected.to be_present }

    context 'when the user cannot read the security configuration' do
      let(:current_user) { reporter }

      it { is_expected.to be_nil }
    end

    context 'when security and compliance is disabled' do
      before do
        project.project_feature.update!(security_and_compliance_access_level: ProjectFeature::DISABLED)
      end

      it { is_expected.to be_nil }
    end

    context 'when the repository is disabled' do
      before do
        project.project_feature.update!(
          repository_access_level: ProjectFeature::DISABLED,
          merge_requests_access_level: ProjectFeature::DISABLED,
          builds_access_level: ProjectFeature::DISABLED
        )
      end

      it { is_expected.to be_nil }
    end
  end
end
