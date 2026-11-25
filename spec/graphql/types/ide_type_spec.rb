# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Ide'], feature_category: :web_ide do
  specify { expect(described_class.graphql_name).to eq('Ide') }

  it 'has the expected fields' do
    expected_fields = %w[
      codeSuggestionsEnabled
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe '#code_suggestions_enabled' do
    include GraphqlHelpers

    let_it_be(:user) { create(:user) }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :access_code_suggestions).and_return(true)
    end

    it 'checks the ability for the user behind the UserPresenter' do
      expect(resolve_field(:code_suggestions_enabled, UserPresenter.new(user), current_user: user)).to be(true)
    end
  end

  it 'declares read_user as the permission its parent checks for a granular token' do
    directive = described_class.directives.find { |d| d.is_a?(::Directives::Authz::GranularScope) }

    expect(directive.arguments[:parent_authorizes]).to eq(%w[read_user])
  end
end
