# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe BackfillMemberRolesUuid, migration: :gitlab_main_org, feature_category: :permissions do
  let(:organizations) { table(:organizations) }
  let(:member_roles) { table(:member_roles) }
  let(:admin_roles) { table(:admin_roles) }

  let(:organization) { organizations.create!(name: 'org', path: 'org') }

  let!(:role) do
    member_roles.create!(name: 'Admin reader', permissions: { read_admin_users: true },
      organization_id: organization.id)
  end

  let!(:role_with_uuid) do
    member_roles.create!(name: 'Other admin', permissions: { read_admin_users: true },
      organization_id: organization.id).reload
  end

  before do
    member_roles.where(id: role.id).update_all(uuid: nil)
    admin_roles.where(id: role.id).update_all(uuid: nil)
  end

  it 'gives each role without a UUID a UUIDv7' do
    migrate!

    expect(Gitlab::UUID.v7?(role.reload.uuid)).to be(true)
  end

  it 'keeps existing UUIDs' do
    expect { migrate! }.not_to change { role_with_uuid.reload.uuid }
  end

  it 'copies the UUID to the admin role copy through the sync trigger' do
    migrate!

    expect(admin_roles.find(role.id).uuid).to eq(role.reload.uuid)
  end
end
