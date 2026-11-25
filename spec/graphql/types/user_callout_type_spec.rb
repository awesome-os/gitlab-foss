# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['UserCallout'] do
  specify { expect(described_class.graphql_name).to eq('UserCallout') }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(:feature_name, :dismissed_at)
  end

  it 'declares read_user as the permission its parent checks for a granular token' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_user])
  end
end
