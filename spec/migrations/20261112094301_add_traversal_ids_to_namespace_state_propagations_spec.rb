# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe AddTraversalIdsToNamespaceStatePropagations, migration: :gitlab_main_org, feature_category: :groups_and_projects do
  let(:organization) { table(:organizations).create!(name: 'Organization', path: 'organization') }
  let(:namespace) do
    table(:namespaces).create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

  let(:propagations) { table(:namespace_state_propagations) }

  it 'adds the column to a table that already has records' do
    propagation = propagations.create!(namespace_id: namespace.id, source_state: 0, target_state: 1, status: 0)

    migrate!

    propagations.reset_column_information

    expect(propagation.reload.traversal_ids).to eq([])
    expect(propagations.columns_hash['traversal_ids']).to have_attributes(null: false, default: nil)
  end
end
