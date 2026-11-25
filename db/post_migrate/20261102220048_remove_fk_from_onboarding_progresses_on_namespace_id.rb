# frozen_string_literal: true

class RemoveFkFromOnboardingProgressesOnNamespaceId < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  FK_NAME = :fk_rails_2ccfd420cc

  def up
    return unless table_exists?(:onboarding_progresses)

    with_lock_retries do
      remove_foreign_key_if_exists :onboarding_progresses, :namespaces, column: :namespace_id, name: FK_NAME
    end
  end

  def down
    return unless table_exists?(:onboarding_progresses)

    add_concurrent_foreign_key :onboarding_progresses, :namespaces,
      column: :namespace_id, on_delete: :cascade, name: FK_NAME
  end
end
