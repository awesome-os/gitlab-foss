# frozen_string_literal: true

class AddContentKeyToMobileDevicePushSubscriptions < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  CONSTRAINT_NAME = 'check_mobile_device_push_subscriptions_content_key_size'

  def up
    with_lock_retries do
      # Encrypted at rest (`encrypts :content_key`), hence jsonb.
      add_column :mobile_device_push_subscriptions, :content_key, :jsonb, if_not_exists: true
    end

    # The encrypted 44-character key takes about 160 bytes.
    add_check_constraint :mobile_device_push_subscriptions, 'octet_length(content_key::text) <= 1024', CONSTRAINT_NAME
  end

  def down
    with_lock_retries do
      remove_column :mobile_device_push_subscriptions, :content_key, if_exists: true
    end
  end
end
