# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe BackfillNullShareWithGroupLockOnNamespaces, feature_category: :groups_and_projects do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }

  let(:organization) { organizations.create!(name: 'Default', path: 'default') }
  let!(:null_group) { create_group('null-lock', nil) }
  let!(:unlocked_group) { create_group('unlocked', false) }
  let!(:locked_group) { create_group('locked', true) }

  def create_group(path, share_with_group_lock)
    namespaces.create!(
      name: path, path: path, type: 'Group', organization_id: organization.id,
      share_with_group_lock: share_with_group_lock
    )
  end

  it 'sets a NULL lock to true and leaves the others alone' do
    migrate!

    expect(null_group.reload.share_with_group_lock).to be(true)
    expect(unlocked_group.reload.share_with_group_lock).to be(false)
    expect(locked_group.reload.share_with_group_lock).to be(true)
  end
end
