# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['X509Certificate'], feature_category: :source_code_management do
  specify { expect(described_class.graphql_name).to eq('X509Certificate') }

  it 'contains attributes for X.509 certifcates' do
    expect(described_class).to have_graphql_fields(
      :certificate_status, :created_at, :email, :id, :serial_number, :subject,
      :subject_key_identifier, :updated_at, :x509_issuer
    )
  end

  it 'skips granular token authorization because the parent authorizes' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:skip_reason]).to eq('parent_authorizes')
    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_commit_signature])
  end
end
