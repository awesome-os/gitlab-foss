# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::RenameStartExportPermissionInGranularScopes, feature_category: :permissions do
  let(:granular_scopes) { table(:granular_scopes) }
  let(:organization) { table(:organizations).create!(name: 'Organization', path: 'organization') }

  let!(:renamed_scope) { create_scope(%w[start_export read_code]) }
  let!(:not_renamed_scope) { create_scope(%w[start_group_export read_wiki]) }
  let!(:both_names_scope) { create_scope(%w[start_export start_group_export]) }
  let!(:already_held_scope) { create_scope(%w[create_export start_export]) }
  let!(:untouched_scope) { create_scope(%w[read_export read_code]) }

  subject(:perform_migration) do
    described_class.new(
      start_cursor: [renamed_scope.id],
      end_cursor: [untouched_scope.id],
      batch_table: :granular_scopes,
      batch_column: :id,
      sub_batch_size: 2,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    ).perform
  end

  it 'replaces start_export and start_group_export with create_export' do
    perform_migration

    expect(permissions_of(renamed_scope)).to match_array(%w[create_export read_code])
    expect(permissions_of(not_renamed_scope)).to match_array(%w[create_export read_wiki])
  end

  it 'keeps create_export once' do
    perform_migration

    expect(permissions_of(both_names_scope)).to eq(%w[create_export])
    expect(permissions_of(already_held_scope)).to eq(%w[create_export])
  end

  it 'leaves scopes without either name untouched' do
    expect { perform_migration }.not_to change { permissions_of(untouched_scope) }
  end

  it 'resolves create_export to the raw permission start_group_export' do
    perform_migration

    expect(Authz::GranularScope.find(renamed_scope.id).expanded_permissions).to include(:start_group_export)
  end

  def create_scope(permissions)
    granular_scopes.create!(organization_id: organization.id, permissions: permissions, access: 0)
  end

  def permissions_of(scope)
    scope.reload.permissions
  end
end
