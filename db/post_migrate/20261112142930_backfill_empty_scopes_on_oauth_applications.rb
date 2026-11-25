# frozen_string_literal: true

class BackfillEmptyScopesOnOauthApplications < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  milestone '19.7'

  # On GitLab.com, no application with this id or a higher one has empty scopes (checked 2026-11-13).
  MAX_ID = 175_000

  # About 48k rows below MAX_ID on GitLab.com (11,060 with empty scopes) -> about 483 batches of 100.
  BATCH_SIZE = 100

  # Doorkeeper lets an application with empty scopes request any configured scope.
  # Same values as Doorkeeper.config.scopes on GitLab.com, without the granular marker.
  SCOPES = 'api read_api read_user create_runner manage_runner k8s_proxy self_rotate mcp mcp_orbit ' \
    'read_repository write_repository read_registry write_registry read_virtual_registry ' \
    'write_virtual_registry read_observability write_observability ai_features sudo admin_mode ' \
    'read_service_ping openid profile email ai_workflows user:*'

  def up
    return unless Gitlab.com_except_jh?

    define_batchable_model(:oauth_applications).where(id: ...MAX_ID).each_batch(of: BATCH_SIZE) do |batch|
      batch.where(scopes: '').update_all(scopes: SCOPES)
    end
  end

  # @note Below MAX_ID, only backfilled rows can hold this exact list: no row had it on 2026-11-13,
  #   the UI hides some of these scopes, and the API cannot update scopes.
  #   Reversibility is tested by the reversible_migration example in the migration spec.
  def down
    return unless Gitlab.com_except_jh?

    define_batchable_model(:oauth_applications).where(id: ...MAX_ID).each_batch(of: BATCH_SIZE) do |batch|
      batch.where(scopes: SCOPES).update_all(scopes: '')
    end
  end
end
