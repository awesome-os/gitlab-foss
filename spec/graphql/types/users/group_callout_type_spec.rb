# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['UserGroupCallout'], feature_category: :user_management do
  specify { expect(described_class.graphql_name).to eq('UserGroupCallout') }

  it 'has all the required fields' do
    expect(described_class).to have_graphql_fields(:dismissed_at, :feature_name, :group_id)
  end

  specify { expect(described_class).to require_graphql_authorizations(:read_user) }

  it 'declares read_user as the permission its parent checks for a granular token' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_user])
  end
end
