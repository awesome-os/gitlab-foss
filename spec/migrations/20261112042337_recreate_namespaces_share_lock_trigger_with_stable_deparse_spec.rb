# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RecreateNamespacesShareLockTriggerWithStableDeparse, migration: :gitlab_main_org,
  feature_category: :permissions do
  let(:organizations) { table(:organizations) }
  let(:users) { table(:users) }
  let(:namespaces) { table(:namespaces) }
  let(:events) { table(:authz_refresh_events) }

  let(:organization) { organizations.create!(name: 'org', path: 'org') }

  let(:group) do
    namespaces.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

  def trigger_definition
    ApplicationRecord.connection.select_value(<<~SQL)
      SELECT pg_get_triggerdef(oid) FROM pg_trigger
      WHERE tgname = 'trigger_authz_refresh_on_namespaces_share_lock_update'
    SQL
  end

  def queued_share_locks
    events.where(target_type: 6).pluck(:target_id)
  end

  describe '#up' do
    it 'removes the array coercion from the definition and keeps the trigger firing', :aggregate_failures do
      migrate!

      expect(trigger_definition).not_to include('ARRAY')

      group.update!(share_with_group_lock: true)

      expect(queued_share_locks).to contain_exactly(group.id)
    end

    it 'queues a personal namespace share-lock change through the User branch' do
      migrate!

      owner = users.create!(email: 'owner@example.com', username: 'owner', projects_limit: 10,
        organization_id: organization.id)
      user_namespace = namespaces.create!(
        name: 'owner', path: 'owner', type: 'User', organization_id: organization.id, owner_id: owner.id
      )

      user_namespace.update!(share_with_group_lock: true)

      expect(queued_share_locks).to contain_exactly(user_namespace.id)
    end

    it 'still ignores namespace types that never grant access themselves' do
      migrate!

      project_namespace = namespaces.create!(
        name: 'project', path: 'project', type: 'Project', organization_id: organization.id
      )
      project_namespace.update!(share_with_group_lock: true)

      expect(queued_share_locks).to be_empty
    end
  end

  describe '#down' do
    it 'still fires after rollback', :aggregate_failures do
      migrate!
      schema_migrate_down!

      expect(trigger_definition).to include('ARRAY')

      group.update!(share_with_group_lock: true)

      expect(queued_share_locks).to contain_exactly(group.id)
    end
  end
end
