# frozen_string_literal: true

class RemoveLegacyColumnsFromPushRules < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  TABLE_NAME = :push_rules
  IS_SAMPLE_INDEX_NAME = 'index_push_rules_on_is_sample'
  ORGANIZATION_ID_INDEX_NAME = 'index_push_rules_on_organization_id'

  def up
    with_lock_retries do
      remove_column TABLE_NAME, :is_sample, if_exists: true
      remove_column TABLE_NAME, :organization_id, if_exists: true
    end
  end

  def down
    with_lock_retries do
      add_column TABLE_NAME, :is_sample, :boolean, default: false, if_not_exists: true
      add_column TABLE_NAME, :organization_id, :bigint, if_not_exists: true
    end

    add_concurrent_index TABLE_NAME, :is_sample, where: 'is_sample', name: IS_SAMPLE_INDEX_NAME
    add_concurrent_index TABLE_NAME, :organization_id, name: ORGANIZATION_ID_INDEX_NAME
  end
end
