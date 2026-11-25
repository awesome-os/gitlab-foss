# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomAttribute'], feature_category: :groups_and_projects do
  it 'has the expected fields' do
    expected_fields = %w[key value]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it 'requires read_custom_attribute on the project, group or instance from a granular token', :aggregate_failures do
    directives = described_class.directives.select { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directives.map { |d| d.arguments[:boundary_type] }).to contain_exactly('project', 'group', 'instance')
    expect(directives.map { |d| d.arguments[:permissions] }).to all(eq(%w[read_custom_attribute]))
  end
end
