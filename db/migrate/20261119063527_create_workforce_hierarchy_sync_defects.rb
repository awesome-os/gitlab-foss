# frozen_string_literal: true

class CreateWorkforceHierarchySyncDefects < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  SHARDING_KEY_CONSTRAINT = 'check_workforce_hierarchy_sync_defects_sharding_key'
  LOCATOR_CONSTRAINT = 'check_workforce_hierarchy_sync_defects_locator'
  LISTING_INDEX = 'index_workforce_hierarchy_sync_defects_on_hierarchy_and_id'
  SUBJECT_KIND_INDEX = 'index_workforce_hierarchy_sync_defects_on_hierarchy_kind_and_id'

  def change
    create_table :workforce_hierarchy_sync_defects do |t|
      # Both indexes below lead with workforce_hierarchy_id, so they also serve the foreign key.
      t.references :workforce_hierarchy, null: false, index: false, foreign_key: false
      t.references :group, null: true, index: true, foreign_key: false
      t.references :organization, null: true, index: true, foreign_key: false
      t.datetime_with_timezone :created_at, null: false
      t.integer :row_number
      t.integer :subject_kind, null: false, limit: 2
      t.integer :reason, null: false, limit: 2
      t.text :external_xid, limit: 255
      t.text :related_xid, limit: 255

      # Keyset pagination of the listing, with and without the subject kind filter.
      t.index [:workforce_hierarchy_id, :id], name: LISTING_INDEX
      t.index [:workforce_hierarchy_id, :subject_kind, :id], name: SUBJECT_KIND_INDEX

      t.check_constraint 'num_nonnulls(group_id, organization_id) = 1', name: SHARDING_KEY_CONSTRAINT
      # A defect is located by the row's own identifier or, when it has none, by its position in the report.
      t.check_constraint 'num_nonnulls(external_xid, row_number) >= 1', name: LOCATOR_CONSTRAINT
    end
  end
end
