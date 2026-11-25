# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['NamespaceSettings'], feature_category: :groups_and_projects do
  it { expect(described_class.graphql_name).to eq('NamespaceSettings') }

  it { expect(described_class).to require_graphql_authorizations(:admin_group) }

  it 'requires read_namespace_setting on the group from a granular token', :aggregate_failures do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:permissions]).to eq(%w[read_namespace_setting])
    expect(directive.arguments[:boundary]).to eq('namespace')
    expect(directive.arguments[:boundary_type]).to eq('group')
  end

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:step_up_auth_required_oauth_provider)
  end
end
