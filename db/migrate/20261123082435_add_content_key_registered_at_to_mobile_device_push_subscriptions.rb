# frozen_string_literal: true

class AddContentKeyRegisteredAtToMobileDevicePushSubscriptions < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :mobile_device_push_subscriptions, :content_key_registered_at, :datetime_with_timezone
  end
end
