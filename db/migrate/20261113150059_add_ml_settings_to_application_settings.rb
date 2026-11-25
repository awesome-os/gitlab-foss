# frozen_string_literal: true

class AddMlSettingsToApplicationSettings < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  CONSTRAINT_NAME = 'check_application_settings_ml_settings_is_hash'
  SIZE_CONSTRAINT_NAME = 'check_application_settings_ml_settings_size'

  def up
    with_lock_retries do
      add_column :application_settings, :ml_settings, :jsonb, default: {}, null: false, if_not_exists: true
    end

    add_check_constraint :application_settings, "(jsonb_typeof(ml_settings) = 'object')", CONSTRAINT_NAME
    add_check_constraint :application_settings, 'octet_length(ml_settings::text) <= 65536', SIZE_CONSTRAINT_NAME
  end

  def down
    remove_check_constraint :application_settings, SIZE_CONSTRAINT_NAME
    remove_check_constraint :application_settings, CONSTRAINT_NAME

    with_lock_retries do
      remove_column :application_settings, :ml_settings, if_exists: true
    end
  end
end
