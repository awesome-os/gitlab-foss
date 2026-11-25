# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe CopyUuidInSyncMemberRolesToAdminRoles, migration: :gitlab_main_org, feature_category: :permissions do
  let(:organizations) { table(:organizations) }
  let(:member_roles) { table(:member_roles) }
  let(:admin_roles) { table(:admin_roles) }

  let(:organization) { organizations.create!(name: 'org', path: 'org') }

  def create_admin_member_role
    member_roles.create!(name: 'Admin reader', permissions: { read_admin_users: true },
      organization_id: organization.id)
  end

  context 'when an admin role is created' do
    before do
      migrate!
    end

    it 'copies the UUID' do
      role = create_admin_member_role.reload

      expect(admin_roles.find(role.id).uuid).to eq(role.uuid)
    end
  end

  context 'when an admin role copy has a different UUID' do
    let!(:role) { create_admin_member_role.reload }

    before do
      admin_roles.where(id: role.id).update_all(uuid: SecureRandom.uuid)
      migrate!
    end

    it 'copies the UUID when the role is updated' do
      member_roles.where(id: role.id).update_all(name: 'Renamed')

      expect(admin_roles.find(role.id).uuid).to eq(role.uuid)
    end
  end

  describe '#down' do
    it 'stops copying the UUID' do
      migrate!
      schema_migrate_down!

      role = create_admin_member_role.reload

      expect(admin_roles.find(role.id).uuid).not_to eq(role.uuid)
    end
  end
end
