# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Blame::BlameType, feature_category: :source_code_management do
  include GraphqlHelpers

  specify { expect(described_class.graphql_name).to eq('Blame') }

  specify do
    expect(described_class).to have_graphql_fields(
      :first_line,
      :groups
    ).at_least
  end

  it 'skips granular token authorization because the parent authorizes' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:skip_reason]).to eq('parent_authorizes')
    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_repository_blob])
  end
end
