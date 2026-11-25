# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Snippets::Destroy, feature_category: :source_code_management do
  specify { expect(described_class).to require_graphql_authorizations(:delete_snippet) }
end
