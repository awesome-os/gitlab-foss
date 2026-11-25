# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Snippets::Update, feature_category: :source_code_management do
  specify { expect(described_class).to require_graphql_authorizations(:update_snippet) }
end
