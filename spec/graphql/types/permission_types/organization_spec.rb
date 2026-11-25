# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Organization, feature_category: :organization do
  specify { expect(described_class.graphql_name).to eq('OrganizationPermissions') }
  specify { expect(described_class).to have_graphql_field(:read_organization) }
end
