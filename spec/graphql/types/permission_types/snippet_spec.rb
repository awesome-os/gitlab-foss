# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Snippet, feature_category: :source_code_management do
  it 'returns the snippets permissions' do
    expected_permissions = [
      :create_note, :award_emoji, :read_snippet, :update_snippet, :admin_snippet, :delete_snippet, :report_snippet
    ]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end

  it 'answers adminSnippet from delete_snippet, like deleteSnippet' do
    expect(described_class.fields['adminSnippet'].method_sym).to eq(:can_delete_snippet?)
    expect(described_class.fields['deleteSnippet'].method_sym).to eq(:can_delete_snippet?)
  end

  it 'skips granular token authorization because the parent authorizes' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:skip_reason]).to eq('parent_authorizes')
    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_snippet])
  end
end
