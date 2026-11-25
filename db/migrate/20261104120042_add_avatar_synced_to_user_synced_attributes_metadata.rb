# frozen_string_literal: true

class AddAvatarSyncedToUserSyncedAttributesMetadata < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  def up
    with_lock_retries do
      add_column :user_synced_attributes_metadata, :avatar_synced, :boolean, default: false, if_not_exists: true
      add_column :user_synced_attributes_metadata, :avatar_ldap_checksum, :text, if_not_exists: true
    end

    add_text_limit :user_synced_attributes_metadata, :avatar_ldap_checksum, 64
  end

  def down
    with_lock_retries do
      remove_column :user_synced_attributes_metadata, :avatar_synced, if_exists: true
      remove_column :user_synced_attributes_metadata, :avatar_ldap_checksum, if_exists: true
    end
  end
end
