# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['X509Issuer'] do
  specify { expect(described_class.graphql_name).to eq('X509Issuer') }

  it 'contains attributes for X.509 issuers' do
    expect(described_class).to have_graphql_fields(
      :created_at, :crl_url, :id, :subject, :subject_key_identifier, :updated_at
    )
  end

  it 'skips granular token authorization because the parent authorizes' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:skip_reason]).to eq('parent_authorizes')
    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_commit_signature])
  end
end
