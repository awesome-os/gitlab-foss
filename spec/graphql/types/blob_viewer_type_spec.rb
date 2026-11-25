# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['BlobViewer'], feature_category: :source_code_management do
  it 'has the correct fields' do
    expected_fields = [:type, :load_async, :too_large, :collapsed,
      :render_error, :file_type, :loading_partial_name]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'skips granular token authorization because the parent authorizes' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:skip_reason]).to eq('parent_authorizes')
    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_repository_blob])
  end
end
