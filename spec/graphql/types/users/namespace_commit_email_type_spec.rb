# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['NamespaceCommitEmail'], feature_category: :user_profile do
  it 'has the correct fields' do
    expected_fields = [
      :id,
      :email,
      :namespace,
      :created_at,
      :updated_at
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  specify { expect(described_class).to require_graphql_authorizations(:read_user_email_address) }

  it 'declares read_user_email as the permission its parent checks for a granular token' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_user_email])
  end
end
