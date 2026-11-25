# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe BackfillAdminRolesUuid, migration: :gitlab_main_org, feature_category: :permissions do
  let(:organizations) { table(:organizations) }
  let(:member_roles) { table(:member_roles) }
  let(:admin_roles) { table(:admin_roles) }

  let(:organization) { organizations.create!(name: 'org', path: 'org') }

  let!(:role) do
    member_roles.create!(name: 'Admin reader', permissions: { read_admin_users: true },
      organization_id: organization.id).reload
  end

  let!(:other_admin_role) do
    admin_roles.create!(name: 'Not a copy', permissions: {}, organization_id: organization.id)
  end

  before do
    admin_roles.update_all(uuid: nil)
  end

  it 'gives each copy the UUID of its member role' do
    migrate!

    expect(admin_roles.find(role.id).uuid).to eq(role.uuid)
  end

  it 'gives an admin role without a member role a UUIDv7' do
    migrate!

    expect(Gitlab::UUID.v7?(other_admin_role.reload.uuid)).to be(true)
  end
end
